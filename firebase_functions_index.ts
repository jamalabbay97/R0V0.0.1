/// <reference path="./firebase-functions-shims.d.ts" />

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const ALLOWED_ROLES = new Set(['employee', 'manager', 'admin']);
const ALLOWED_REPORT_TYPES = new Set([
    'activity',
    'daily',
    'r0',
    'machines-equipment-stopped',
    'truck-tracking',
]);

const USERS_COLLECTION = 'users';
const REPORTS_COLLECTION = 'reports';

type AppRole = 'employee' | 'manager' | 'admin';

interface SetUserRoleRequest {
    uid?: string;
    role?: string;
}

interface SetUserRoleResponse {
    success: boolean;
    uid: string;
    role: AppRole;
}

interface UpsertReportRequest {
    firestoreId?: string;
    description?: string;
    date?: string;
    group?: string;
    type?: string;
    additionalData?: Record<string, unknown>;
    localId?: number;
}

interface UpsertReportResponse {
    success: true;
    reportId: string;
}

interface DeleteReportRequest {
    firestoreId?: string;
}

interface ListMyReportsRequest {
    limit?: number;
    startAfter?: string;
}

interface SerializableReport {
    id: string;
    description: string;
    group: string;
    type: string;
    userId: string;
    date: string;
    createdAt: string | null;
    updatedAt: string | null;
    localId: number | null;
    additionalData: Record<string, unknown>;
}

interface ListMyReportsResponse {
    reports: SerializableReport[];
    nextCursor: string | null;
}

interface DashboardSummaryResponse {
    currentMonth: {
        totalReports: number;
        byType: Record<string, number>;
    };
}

function assertSignedIn(context: functions.https.CallableContext): functions.auth.UserRecord['uid'] {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication is required.');
    }

    return uid;
}

function assertAdmin(context: functions.https.CallableContext): functions.auth.UserRecord['uid'] {
    const uid = assertSignedIn(context);
    if (context.auth?.token?.role !== 'admin') {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only admins can perform this action.',
        );
    }

    return uid;
}

function ensureNonEmptyString(value: unknown, fieldName: string): string {
    if (typeof value !== 'string' || !value.trim()) {
        throw new functions.https.HttpsError('invalid-argument', `${fieldName} is required.`);
    }

    return value.trim();
}

function parseDateToTimestamp(isoDateLike: unknown): Date {
    if (typeof isoDateLike !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'date must be an ISO-8601 string.');
    }

    const parsed = new Date(isoDateLike);
    if (Number.isNaN(parsed.getTime())) {
        throw new functions.https.HttpsError('invalid-argument', 'date is invalid.');
    }

    return parsed;
}

function mapReportSnapshot(snapshot: any): SerializableReport {
    const data = snapshot.data();

    const date = data.date && typeof data.date.toDate === 'function'
        ? data.date.toDate().toISOString()
        : new Date(0).toISOString();

    const createdAt = data.createdAt && typeof data.createdAt.toDate === 'function'
        ? data.createdAt.toDate().toISOString()
        : null;

    const updatedAt = data.updatedAt && typeof data.updatedAt.toDate === 'function'
        ? data.updatedAt.toDate().toISOString()
        : null;

    return {
        id: snapshot.id,
        description: typeof data.description === 'string' ? data.description : '',
        group: typeof data.group === 'string' ? data.group : '',
        type: typeof data.type === 'string' ? data.type : '',
        userId: typeof data.userId === 'string' ? data.userId : '',
        date,
        createdAt,
        updatedAt,
        localId: typeof data.localId === 'number' ? data.localId : null,
        additionalData: typeof data.additionalData === 'object' && data.additionalData !== null
            ? data.additionalData as Record<string, unknown>
            : {},
    };
}

export const setUserRole = functions.https.onCall<SetUserRoleRequest, SetUserRoleResponse>(
    async (data: SetUserRoleRequest, context: functions.https.CallableContext) => {
        const actorUid = assertAdmin(context);

        const uid = ensureNonEmptyString(data?.uid, 'uid');
        const role = ensureNonEmptyString(data?.role, 'role').toLowerCase();

        if (!ALLOWED_ROLES.has(role)) {
            throw new functions.https.HttpsError('invalid-argument', 'role is invalid.');
        }

        if (actorUid === uid && role !== 'admin') {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Admins cannot demote themselves.',
            );
        }

        const validatedRole = role as AppRole;

        await admin.auth().setCustomUserClaims(uid, { role: validatedRole });
        await admin.firestore().collection(USERS_COLLECTION).doc(uid).set(
            {
                role: validatedRole,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
        );

        return { success: true, uid, role: validatedRole };
    },
);

export const bootstrapUserRecord = functions.auth.user().onCreate(
    async (user: functions.auth.UserRecord) => {
        await admin.firestore().collection(USERS_COLLECTION).doc(user.uid).set(
            {
                email: user.email ?? null,
                displayName: user.displayName ?? null,
                role: 'employee',
                allowedReports: [],
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
        );
    },
);

export const cleanupDeletedUserData = functions.auth.user().onDelete(
    async (user: functions.auth.UserRecord) => {
        const db = admin.firestore();
        const reportsSnapshot = await db
            .collection(REPORTS_COLLECTION)
            .where('userId', '==', user.uid)
            .get();

        if (!reportsSnapshot.empty) {
            const chunks: any[][] = [];
            let current: any[] = [];

            for (const doc of reportsSnapshot.docs) {
                current.push(doc);
                if (current.length === 500) {
                    chunks.push(current);
                    current = [];
                }
            }

            if (current.length > 0) {
                chunks.push(current);
            }

            for (const chunk of chunks) {
                const batch = db.batch();
                for (const reportDoc of chunk) {
                    batch.delete(reportDoc.ref);
                }
                await batch.commit();
            }
        }

        await db.collection(USERS_COLLECTION).doc(user.uid).delete().catch(() => undefined);
    },
);

export const upsertMyReport = functions.https.onCall<UpsertReportRequest, UpsertReportResponse>(
    async (data: UpsertReportRequest, context: functions.https.CallableContext) => {
        const uid = assertSignedIn(context);

        const description = ensureNonEmptyString(data?.description, 'description');
        const group = ensureNonEmptyString(data?.group, 'group');
        const type = ensureNonEmptyString(data?.type, 'type').toLowerCase();
        if (!ALLOWED_REPORT_TYPES.has(type)) {
            throw new functions.https.HttpsError('invalid-argument', 'type is invalid.');
        }

        const date = parseDateToTimestamp(data?.date);

        const additionalData = typeof data?.additionalData === 'object' && data.additionalData !== null
            ? data.additionalData
            : {};

        const payload: Record<string, unknown> = {
            userId: uid,
            description,
            group,
            type,
            date,
            additionalData,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (typeof data?.localId === 'number') {
            payload.localId = data.localId;
        }

        const db = admin.firestore();
        const firestoreId = typeof data?.firestoreId === 'string' ? data.firestoreId.trim() : '';

        if (firestoreId) {
            const docRef = db.collection(REPORTS_COLLECTION).doc(firestoreId);
            const snapshot = await docRef.get();
            if (!snapshot.exists) {
                throw new functions.https.HttpsError('not-found', 'Report was not found.');
            }

            if (snapshot.data()?.userId !== uid) {
                throw new functions.https.HttpsError(
                    'permission-denied',
                    'You can only update your own reports.',
                );
            }

            await docRef.set(payload, { merge: true });
            return { success: true, reportId: docRef.id };
        }

        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
        const created = await db.collection(REPORTS_COLLECTION).add(payload);
        return { success: true, reportId: created.id };
    },
);

export const deleteMyReport = functions.https.onCall<DeleteReportRequest, { success: true }>(
    async (data: DeleteReportRequest, context: functions.https.CallableContext) => {
        const uid = assertSignedIn(context);
        const firestoreId = ensureNonEmptyString(data?.firestoreId, 'firestoreId');

        const docRef = admin.firestore().collection(REPORTS_COLLECTION).doc(firestoreId);
        const snapshot = await docRef.get();

        if (!snapshot.exists) {
            throw new functions.https.HttpsError('not-found', 'Report was not found.');
        }

        if (snapshot.data()?.userId !== uid) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'You can only delete your own reports.',
            );
        }

        await docRef.delete();
        return { success: true };
    },
);

export const listMyReports = functions.https.onCall<ListMyReportsRequest, ListMyReportsResponse>(
    async (data: ListMyReportsRequest, context: functions.https.CallableContext) => {
        const uid = assertSignedIn(context);
        const limit = typeof data?.limit === 'number'
            ? Math.min(Math.max(Math.floor(data.limit), 1), 200)
            : 50;

        const db = admin.firestore();
        let query = db
            .collection(REPORTS_COLLECTION)
            .where('userId', '==', uid)
            .orderBy('date', 'desc')
            .limit(limit);

        if (typeof data?.startAfter === 'string' && data.startAfter.trim()) {
            const cursorDoc = await db.collection(REPORTS_COLLECTION).doc(data.startAfter).get();
            if (cursorDoc.exists) {
                query = query.startAfter(cursorDoc);
            }
        }

        const snapshot = await query.get();
        const reports = snapshot.docs.map(mapReportSnapshot);
        const nextCursor = snapshot.docs.length === limit
            ? snapshot.docs[snapshot.docs.length - 1].id
            : null;

        return { reports, nextCursor };
    },
);

export const getMyDashboardSummary = functions.https.onCall<Record<string, never>, DashboardSummaryResponse>(
    async (_: Record<string, never>, context: functions.https.CallableContext) => {
        const uid = assertSignedIn(context);

        const startOfMonth = new Date();
        startOfMonth.setUTCDate(1);
        startOfMonth.setUTCHours(0, 0, 0, 0);

        const snapshot = await admin.firestore()
            .collection(REPORTS_COLLECTION)
            .where('userId', '==', uid)
            .where('date', '>=', startOfMonth)
            .get();

        const byType: Record<string, number> = {};
        for (const doc of snapshot.docs) {
            const type = typeof doc.data().type === 'string' ? doc.data().type : 'unknown';
            byType[type] = (byType[type] ?? 0) + 1;
        }

        return {
            currentMonth: {
                totalReports: snapshot.size,
                byType,
            },
        };
    },
);