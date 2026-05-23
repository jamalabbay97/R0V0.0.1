/// <reference path="./firebase-functions-shims.d.ts" />

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { GoogleAuth } from 'google-auth-library';

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
const AUDIT_LOGS_COLLECTION = 'audit_logs';

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

async function writeAuditLog(params: {
    actorUid: string;
    action: string;
    entityType: string;
    entityId: string;
    before?: Record<string, unknown> | null;
    after?: Record<string, unknown> | null;
    result?: 'success' | 'failure';
}): Promise<void> {
    await admin.firestore().collection(AUDIT_LOGS_COLLECTION).add({
        actorUid: params.actorUid,
        action: params.action,
        entityType: params.entityType,
        entityId: params.entityId,
        before: params.before ?? null,
        after: params.after ?? null,
        result: params.result ?? 'success',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
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
        const userRef = admin.firestore().collection(USERS_COLLECTION).doc(uid);
        const beforeSnapshot = await userRef.get();
        const before = beforeSnapshot.exists ? beforeSnapshot.data() ?? null : null;

        await admin.auth().setCustomUserClaims(uid, { role: validatedRole });
        await userRef.set(
            {
                role: validatedRole,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
        );
        await writeAuditLog({
            actorUid,
            action: 'user.role.set',
            entityType: 'user',
            entityId: uid,
            before,
            after: { role: validatedRole },
        });

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
            await writeAuditLog({
                actorUid: uid,
                action: 'report.update',
                entityType: 'report',
                entityId: docRef.id,
                before: snapshot.data() ?? null,
                after: payload,
            });
            return { success: true, reportId: docRef.id };
        }

        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
        const created = await db.collection(REPORTS_COLLECTION).add(payload);
        await writeAuditLog({
            actorUid: uid,
            action: 'report.create',
            entityType: 'report',
            entityId: created.id,
            after: payload,
        });
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

        const before = snapshot.data() ?? null;
        await docRef.delete();
        await writeAuditLog({
            actorUid: uid,
            action: 'report.delete',
            entityType: 'report',
            entityId: firestoreId,
            before,
        });
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

interface GoogleSheetsOperation {
    type: 'appendTemplateRows' | 'appendFlatRows' | 'appendIfDowntimeRows';
    sheetName: string;
    headers?: string[];
    rows?: any[][];
    dateColumnIndex?: number;
    firstDataRowNumber?: number;
    mergeRanges?: { startColumnIndex: number; endColumnIndex: number }[];
    customMerges?: { startRowOffset: number; endRowOffset: number; startColumnIndex: number; endColumnIndex: number }[];
    colorSections?: { startColumnIndex: number; endColumnIndex: number }[];
    separatorColumnIndexes?: number[];
    checkDuplicate?: 'date' | 'r0' | 'truck' | null;
    date?: string;
    poste?: string;
    module?: string;
    rangePrefix?: string;
    rangeSuffix?: string;
}

interface SubmitReportToSheetsRequest {
    reportId?: string;
    action?: string;
    tasks?: GoogleSheetsOperation[];
}

let cachedAccessToken: string | null = null;
let tokenExpiry = 0;

async function getAccessToken(): Promise<string> {
    const now = Date.now();
    if (cachedAccessToken && tokenExpiry > now + 300000) {
        return cachedAccessToken;
    }

    const auth = new GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/spreadsheets'],
    });
    const client = await auth.getClient();
    const token = await client.getAccessToken();
    if (!token.token) {
        throw new Error('Failed to get access token from GoogleAuth');
    }
    cachedAccessToken = token.token;
    tokenExpiry = now + 3600 * 1000;
    return cachedAccessToken as string;
}

function isSameReportDate(rawDate: string, targetDate: string): boolean {
    const d1 = tryNormalizeDate(rawDate);
    const d2 = tryNormalizeDate(targetDate);
    return d1 !== null && d1 === d2;
}

function tryNormalizeDate(val: string): string | null {
    const cleaned = val.trim();
    if (!cleaned) return null;
    
    const match = cleaned.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match) {
        return `${match[1]}-${match[2]}-${match[3]}`;
    }
    
    const parsed = Date.parse(cleaned);
    if (!isNaN(parsed)) {
        const dateObj = new Date(parsed);
        const y = dateObj.getFullYear();
        const m = String(dateObj.getMonth() + 1).padStart(2, '0');
        const d = String(dateObj.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }
    
    return cleaned.toLowerCase().replace(/\s+/g, ' ');
}

function normalizePosteValue(value: unknown): string {
    return String(value ?? '').trim().toLowerCase();
}

function parseDateTime(val: unknown): Date | null {
    if (typeof val !== 'string') return null;
    const cleaned = val.trim();
    if (!cleaned) return null;
    const parsed = Date.parse(cleaned);
    return isNaN(parsed) ? null : new Date(parsed);
}

async function callSheetsApi(
    spreadsheetId: string,
    accessToken: string,
    path: string,
    method: 'GET' | 'POST' | 'PUT',
    body?: any
): Promise<any> {
    const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}${path}`;
    const headers: Record<string, string> = {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
    };
    const response = await fetch(url, {
        method,
        headers,
        body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Sheets API error (${response.status}): ${errorText}`);
    }
    return response.json();
}

async function checkDuplicateDate(
    spreadsheetId: string,
    accessToken: string,
    resolvedSheetName: string,
    targetDate: string
): Promise<boolean> {
    try {
        const response = await callSheetsApi(
            spreadsheetId,
            accessToken,
            `/values/${encodeURIComponent(resolvedSheetName)}!A7:A`,
            'GET'
        );
        const values = response.values || [];
        for (const row of values) {
            if (row && row.length > 0) {
                const rawDate = String(row[0]).trim();
                if (isSameReportDate(rawDate, targetDate)) {
                    return true;
                }
            }
        }
    } catch (e) {
        console.warn(`Error reading sheet ${resolvedSheetName} for duplicate date:`, e);
    }
    return false;
}

async function checkDuplicateR0Report(
    spreadsheetId: string,
    accessToken: string,
    resolvedSheetName: string,
    targetDate: string,
    targetPoste: string,
    targetModule: string
): Promise<boolean> {
    try {
        const response = await callSheetsApi(
            spreadsheetId,
            accessToken,
            `/values/${encodeURIComponent(resolvedSheetName)}!A7:H`,
            'GET'
        );
        const values = response.values || [];
        const normPoste = normalizePosteValue(targetPoste);
        const normModule = normalizePosteValue(targetModule);
        for (const row of values) {
            if (row && row.length >= 8) {
                const rowDate = String(row[0]).trim();
                const rowPoste = normalizePosteValue(row[4]);
                const rowModule = normalizePosteValue(row[7]);
                if (isSameReportDate(rowDate, targetDate) && rowPoste === normPoste && rowModule === normModule) {
                    return true;
                }
            }
        }
    } catch (e) {
        console.warn(`Error reading sheet ${resolvedSheetName} for duplicate R0:`, e);
    }
    return false;
}

async function checkDuplicateTruckReport(
    spreadsheetId: string,
    accessToken: string,
    resolvedSheetName: string,
    targetDate: string,
    targetPoste: string
): Promise<boolean> {
    try {
        const response = await callSheetsApi(
            spreadsheetId,
            accessToken,
            `/values/${encodeURIComponent(resolvedSheetName)}!A7:I`,
            'GET'
        );
        const values = response.values || [];
        const normPoste = normalizePosteValue(targetPoste);
        for (const row of values) {
            if (row && row.length >= 9) {
                const rowDate = String(row[0]).trim();
                const rowPoste = normalizePosteValue(row[8]);
                if (isSameReportDate(rowDate, targetDate) && rowPoste === normPoste) {
                    return true;
                }
            }
        }
    } catch (e) {
        console.warn(`Error reading sheet ${resolvedSheetName} for duplicate truck:`, e);
    }
    return false;
}

async function resolveTemplateInsertRowNumber(
    spreadsheetId: string,
    accessToken: string,
    sheetName: string,
    reportDateValue: string
): Promise<number> {
    const targetDate = parseDateTime(reportDateValue) || new Date(0);
    try {
        const response = await callSheetsApi(
            spreadsheetId,
            accessToken,
            `/values/${encodeURIComponent(sheetName)}!A7:I`,
            'GET'
        );
        const values = response.values || [];
        for (let index = 0; index < values.length; index++) {
            const row = values[index];
            if (!row || row.length === 0) continue;
            const currentDate = parseDateTime(row[0]);
            if (currentDate && targetDate.getTime() > currentDate.getTime()) {
                return index + 7;
            }
        }
        return values.length + 7;
    } catch (e) {
        return 7;
    }
}

async function resolveFlatInsertRowNumber(
    spreadsheetId: string,
    accessToken: string,
    sheetName: string,
    reportDateValue: string,
    dateColumnIndex: number,
    firstDataRowNumber: number
): Promise<number> {
    const targetDate = parseDateTime(reportDateValue) || new Date(0);
    try {
        const response = await callSheetsApi(
            spreadsheetId,
            accessToken,
            `/values/${encodeURIComponent(sheetName)}!A${firstDataRowNumber}:AZ`,
            'GET'
        );
        const values = response.values || [];
        for (let index = 0; index < values.length; index++) {
            const row = values[index];
            if (!row || row.length <= dateColumnIndex) continue;
            const currentDate = parseDateTime(row[dateColumnIndex]);
            if (currentDate && targetDate.getTime() > currentDate.getTime()) {
                return index + firstDataRowNumber;
            }
        }
        return values.length + firstDataRowNumber;
    } catch (e) {
        return firstDataRowNumber;
    }
}

async function ensureIfDowntimeDetailsLayout(
    spreadsheetId: string,
    accessToken: string,
    sheetName: string
): Promise<void> {
    const headers = [
        'jour',
        "Debut d'arret",
        "Fin d'arret",
        "durée d'arret",
        'STS',
        'equipement',
        'designation',
    ];
    await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(sheetName)}!A3?valueInputOption=RAW`, 'PUT', {
        values: [['TNB']]
    });
    await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(sheetName)}!I3?valueInputOption=RAW`, 'PUT', {
        values: [['TSUD M1']]
    });
    await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(sheetName)}!Q3?valueInputOption=RAW`, 'PUT', {
        values: [['TSUD M2']]
    });
    await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(sheetName)}!A4:G4?valueInputOption=RAW`, 'PUT', {
        values: [headers]
    });
    await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(sheetName)}!I4:O4?valueInputOption=RAW`, 'PUT', {
        values: [headers]
    });
    await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(sheetName)}!Q4:W4?valueInputOption=RAW`, 'PUT', {
        values: [headers]
    });
}

interface ColorTheme {
    primary: { red: number; green: number; blue: number };
    secondary: { red: number; green: number; blue: number };
}

const colorThemes: ColorTheme[] = [
    {
        primary: { red: 0.97, green: 0.95, blue: 0.90 },
        secondary: { red: 0.93, green: 0.96, blue: 0.98 },
    },
    {
        primary: { red: 0.95, green: 0.92, blue: 0.96 },
        secondary: { red: 0.90, green: 0.95, blue: 0.92 },
    },
    {
        primary: { red: 0.94, green: 0.97, blue: 0.93 },
        secondary: { red: 0.97, green: 0.94, blue: 0.90 },
    },
    {
        primary: { red: 0.92, green: 0.95, blue: 0.98 },
        secondary: { red: 0.96, green: 0.93, blue: 0.95 },
    },
    {
        primary: { red: 0.96, green: 0.94, blue: 0.92 },
        secondary: { red: 0.92, green: 0.96, blue: 0.94 },
    },
];

function selectColorTheme(sheetName: string, startRowIndex: number): ColorTheme {
    let sum = 0;
    for (let i = 0; i < sheetName.length; i++) {
        sum += sheetName.charCodeAt(i);
    }
    const seed = sum + startRowIndex;
    const paletteIndex = Math.abs(seed) % colorThemes.length;
    return colorThemes[paletteIndex];
}

export const submitReportToSheets = functions.https.onCall<SubmitReportToSheetsRequest, { success: boolean }>(
    async (data: SubmitReportToSheetsRequest, context: functions.https.CallableContext) => {
        try {
            const uid = assertSignedIn(context);

            const reportId = ensureNonEmptyString(data?.reportId, 'reportId');
            const action = ensureNonEmptyString(data?.action, 'action');
            const tasks = data?.tasks;
            if (!Array.isArray(tasks) || tasks.length === 0) {
                throw new functions.https.HttpsError('invalid-argument', 'tasks must be a non-empty array.');
            }

            const db = admin.firestore();
            const reportRef = db.collection(REPORTS_COLLECTION).doc(reportId);
            const reportDoc = await reportRef.get();
            if (!reportDoc.exists) {
                throw new functions.https.HttpsError('not-found', 'Report not found.');
            }
            const reportData = reportDoc.data()!;
            const isOwner = reportData.userId === uid;
            const role = context.auth?.token?.role;
            const isManagerOrAdmin = role === 'admin' || role === 'manager';
            if (!isOwner && !isManagerOrAdmin) {
                throw new functions.https.HttpsError('permission-denied', 'You do not have permission to sync this report.');
            }

            const spreadsheetId = functions.config().sheets?.spreadsheet_id || process.env.GOOGLE_SHEETS_SPREADSHEET_ID;
            if (!spreadsheetId) {
                throw new functions.https.HttpsError('failed-precondition', 'Spreadsheet ID is not configured.');
            }

            const accessToken = await getAccessToken();

            const spreadsheetMeta = await callSheetsApi(spreadsheetId, accessToken, '', 'GET');
            const sheets = spreadsheetMeta.sheets || [];
            const sheetNames = sheets.map((s: any) => s.properties.title as string);
            const sheetIdsByName: Record<string, number> = {};
            for (const s of sheets) {
                sheetIdsByName[s.properties.title] = s.properties.sheetId;
            }

            const getResolvedSheetName = (targetName: string): string => {
                const lowerTarget = targetName.toLowerCase().trim();
                for (const name of sheetNames) {
                    if (name.toLowerCase().trim() === lowerTarget) {
                        return name;
                    }
                }
                return targetName;
            };

            const getSheetId = (sheetName: string): number | null => {
                const name = getResolvedSheetName(sheetName);
                return sheetIdsByName[name] ?? null;
            };

            for (const task of tasks) {
                const taskType = task.type;
                const rawSheetName = ensureNonEmptyString(task.sheetName, 'sheetName');
                let resolvedSheetName = getResolvedSheetName(rawSheetName);

                let sheetId = getSheetId(resolvedSheetName);
                if (sheetId === null) {
                    const addResult = await callSheetsApi(spreadsheetId, accessToken, ':batchUpdate', 'POST', {
                        requests: [{
                            addSheet: { properties: { title: rawSheetName } }
                        }]
                    });
                    const newSheetProp = addResult.replies?.[0]?.addSheet?.properties;
                    if (newSheetProp) {
                        sheetIdsByName[newSheetProp.title] = newSheetProp.sheetId;
                        sheetNames.push(newSheetProp.title);
                        sheetId = newSheetProp.sheetId;
                        resolvedSheetName = newSheetProp.title;
                    } else {
                        throw new Error(`Failed to create sheet "${rawSheetName}"`);
                    }
                }

                if (taskType === 'appendTemplateRows') {
                    const rows = task.rows;
                    if (!rows || rows.length === 0) continue;

                    const checkDuplicate = task.checkDuplicate;
                    if (checkDuplicate === 'date') {
                        const targetDate = ensureNonEmptyString(task.date, 'date');
                        const isDup = await checkDuplicateDate(spreadsheetId, accessToken, resolvedSheetName, targetDate);
                        if (isDup) {
                            throw new functions.https.HttpsError('already-exists', `Un rapport avec la date du jour existe déjà dans ${rawSheetName} (${targetDate}).`);
                        }
                    } else if (checkDuplicate === 'r0') {
                        const targetDate = ensureNonEmptyString(task.date, 'date');
                        const targetPoste = String(task.poste || '');
                        const targetModule = String(task.module || '');
                        const isDup = await checkDuplicateR0Report(spreadsheetId, accessToken, resolvedSheetName, targetDate, targetPoste, targetModule);
                        if (isDup) {
                            throw new functions.https.HttpsError('already-exists', "Un rapport avec la date d'aujourd'hui existe déjà pour ce poste et ce module.");
                        }
                    } else if (checkDuplicate === 'truck') {
                        const targetDate = ensureNonEmptyString(task.date, 'date');
                        const targetPoste = String(task.poste || '');
                        const isDup = await checkDuplicateTruckReport(spreadsheetId, accessToken, resolvedSheetName, targetDate, targetPoste);
                        if (isDup) {
                            throw new functions.https.HttpsError('already-exists', "Un rapport avec la date d'aujourd'hui existe déjà pour ce poste.");
                        }
                    }

                    const firstRow = rows[0];
                    const newDate = firstRow.length > 0 ? String(firstRow[0]) : '';
                    const insertStartRowNumber = await resolveTemplateInsertRowNumber(spreadsheetId, accessToken, resolvedSheetName, newDate);

                    const startRowIndex = insertStartRowNumber - 1;
                    const endRowIndex = startRowIndex + rows.length;

                    await callSheetsApi(spreadsheetId, accessToken, ':batchUpdate', 'POST', {
                        requests: [{
                            insertDimension: {
                                range: {
                                    sheetId: sheetId,
                                    dimension: 'ROWS',
                                    startIndex: startRowIndex,
                                    endIndex: endRowIndex
                                },
                                inheritFromBefore: startRowIndex > 6
                            }
                        }]
                    });

                    await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(resolvedSheetName)}!A${insertStartRowNumber}?valueInputOption=RAW`, 'PUT', {
                        values: rows
                    });

                    const requests: any[] = [];
                    const colorTheme = selectColorTheme(resolvedSheetName, startRowIndex);

                    let maxColCount = 0;
                    for (const r of rows) {
                        if (r.length > maxColCount) maxColCount = r.length;
                    }

                    if (maxColCount > 0) {
                        requests.push({
                            copyPaste: {
                                source: {
                                    sheetId: sheetId,
                                    startRowIndex: 6,
                                    endRowIndex: 7,
                                    startColumnIndex: 0,
                                    endColumnIndex: maxColCount
                                },
                                destination: {
                                    sheetId: sheetId,
                                    startRowIndex: startRowIndex,
                                    endRowIndex: endRowIndex,
                                    startColumnIndex: 0,
                                    endColumnIndex: maxColCount
                                },
                                pasteType: 'PASTE_FORMAT',
                                pasteOrientation: 'NORMAL'
                            }
                        });

                        requests.push({
                            repeatCell: {
                                range: {
                                    sheetId: sheetId,
                                    startRowIndex: startRowIndex,
                                    endRowIndex: endRowIndex,
                                    startColumnIndex: 0,
                                    endColumnIndex: maxColCount
                                },
                                cell: {
                                    userEnteredFormat: {
                                        backgroundColor: colorTheme.primary
                                    }
                                },
                                fields: 'userEnteredFormat.backgroundColor'
                            }
                        });
                    }

                    const mergeRanges = task.mergeRanges || [];
                    for (const mergeRange of mergeRanges) {
                        for (let colIndex = mergeRange.startColumnIndex; colIndex < mergeRange.endColumnIndex; colIndex++) {
                            requests.push({
                                mergeCells: {
                                    range: {
                                        sheetId: sheetId,
                                        startRowIndex: startRowIndex,
                                        endRowIndex: endRowIndex,
                                        startColumnIndex: colIndex,
                                        endColumnIndex: colIndex + 1
                                    },
                                    mergeType: 'MERGE_ALL'
                                }
                            });
                        }
                    }

                    const customMerges = task.customMerges || [];
                    for (const merge of customMerges) {
                        requests.push({
                            mergeCells: {
                                range: {
                                    sheetId: sheetId,
                                    startRowIndex: startRowIndex + merge.startRowOffset,
                                    endRowIndex: startRowIndex + merge.endRowOffset,
                                    startColumnIndex: merge.startColumnIndex,
                                    endColumnIndex: merge.endColumnIndex
                                },
                                mergeType: 'MERGE_ALL'
                            }
                        });
                    }

                    const colorSections = task.colorSections || [];
                    for (const section of colorSections) {
                        requests.push({
                            repeatCell: {
                                range: {
                                    sheetId: sheetId,
                                    startRowIndex: startRowIndex,
                                    endRowIndex: endRowIndex,
                                    startColumnIndex: section.startColumnIndex,
                                    endColumnIndex: section.endColumnIndex
                                },
                                cell: {
                                    userEnteredFormat: {
                                        backgroundColor: colorTheme.secondary
                                    }
                                },
                                fields: 'userEnteredFormat.backgroundColor'
                            }
                        });
                    }

                    const separatorColumnIndexes = task.separatorColumnIndexes || [];
                    for (const colIndex of separatorColumnIndexes) {
                        requests.push({
                            repeatCell: {
                                range: {
                                    sheetId: sheetId,
                                    startRowIndex: startRowIndex,
                                    endRowIndex: endRowIndex,
                                    startColumnIndex: colIndex,
                                    endColumnIndex: colIndex + 1
                                },
                                cell: {
                                    userEnteredFormat: {
                                        backgroundColor: { red: 1, green: 1, blue: 1 }
                                    }
                                },
                                fields: 'userEnteredFormat.backgroundColor'
                            }
                        });
                        requests.push({
                            updateBorders: {
                                range: {
                                    sheetId: sheetId,
                                    startRowIndex: startRowIndex,
                                    endRowIndex: endRowIndex,
                                    startColumnIndex: colIndex,
                                    endColumnIndex: colIndex + 1
                                },
                                top: { style: 'NONE' },
                                bottom: { style: 'NONE' },
                                left: { style: 'NONE' },
                                right: { style: 'NONE' },
                                innerHorizontal: { style: 'NONE' },
                                innerVertical: { style: 'NONE' }
                            }
                        });
                    }

                    if (requests.length > 0) {
                        await callSheetsApi(spreadsheetId, accessToken, ':batchUpdate', 'POST', {
                            requests: requests
                        });
                    }

                } else if (taskType === 'appendFlatRows') {
                    const rows = task.rows;
                    if (!rows || rows.length === 0) continue;

                    const headers = task.headers || [];
                    const dateColumnIndex = typeof task.dateColumnIndex === 'number' ? task.dateColumnIndex : 0;
                    const firstDataRowNumber = typeof task.firstDataRowNumber === 'number' ? task.firstDataRowNumber : 2;

                    try {
                        const headerRes = await callSheetsApi(
                            spreadsheetId,
                            accessToken,
                            `/values/${encodeURIComponent(resolvedSheetName)}!1:1`,
                            'GET'
                        );
                        const headerValues = headerRes.values || [];
                        if (headerValues.length === 0) {
                            await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(resolvedSheetName)}!1:1?valueInputOption=USER_ENTERED`, 'PUT', {
                                values: [headers]
                            });
                        }
                    } catch (e) {
                        await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(resolvedSheetName)}!1:1?valueInputOption=USER_ENTERED`, 'PUT', {
                            values: [headers]
                        });
                    }

                    for (const r of rows) {
                        const newDate = r.length > dateColumnIndex ? String(r[dateColumnIndex]) : '';
                        const insertRowNumber = await resolveFlatInsertRowNumber(spreadsheetId, accessToken, resolvedSheetName, newDate, dateColumnIndex, firstDataRowNumber);

                        const startRowIndex = insertRowNumber - 1;
                        const endRowIndex = startRowIndex + 1;

                        await callSheetsApi(spreadsheetId, accessToken, ':batchUpdate', 'POST', {
                            requests: [{
                                insertDimension: {
                                    range: {
                                        sheetId: sheetId,
                                        dimension: 'ROWS',
                                        startIndex: startRowIndex,
                                        endIndex: endRowIndex
                                    },
                                    inheritFromBefore: startRowIndex > (firstDataRowNumber - 1)
                                }
                            }]
                        });

                        await callSheetsApi(spreadsheetId, accessToken, `/values/${encodeURIComponent(resolvedSheetName)}!A${insertRowNumber}?valueInputOption=RAW`, 'PUT', {
                            values: [r]
                        });
                    }
                } else if (taskType === 'appendIfDowntimeRows') {
                    const rows = task.rows;
                    if (!rows || rows.length === 0) continue;

                    const rangePrefix = ensureNonEmptyString(task.rangePrefix, 'rangePrefix');
                    const rangeSuffix = ensureNonEmptyString(task.rangeSuffix, 'rangeSuffix');

                    // Check if layout needs initializing
                    try {
                        const checkLayoutRes = await callSheetsApi(
                            spreadsheetId,
                            accessToken,
                            `/values/${encodeURIComponent(resolvedSheetName)}!A3`,
                            'GET'
                        );
                        const values = checkLayoutRes.values || [];
                        if (values.length === 0 || !values[0] || values[0].length === 0) {
                            await ensureIfDowntimeDetailsLayout(spreadsheetId, accessToken, resolvedSheetName);
                        }
                    } catch (e) {
                        await ensureIfDowntimeDetailsLayout(spreadsheetId, accessToken, resolvedSheetName);
                    }

                    // Fetch existing range starting from row 5
                    let existingRows: any[][] = [];
                    try {
                        const existingRange = await callSheetsApi(
                            spreadsheetId,
                            accessToken,
                            `/values/${encodeURIComponent(resolvedSheetName)}!${rangePrefix}5:${rangeSuffix}`,
                            'GET'
                        );
                        existingRows = existingRange.values || [];
                    } catch (e) {
                        console.warn(`Error fetching downtime rows range for ${resolvedSheetName}:`, e);
                    }

                    // Count non-empty rows
                    const isNonEmptyRow = (row: any[]): boolean => {
                        if (!row || row.length === 0) return false;
                        return row.some(cell => cell !== null && cell !== undefined && String(cell).trim().length > 0);
                    };
                    const nonEmptyCount = existingRows.filter(isNonEmptyRow).length;

                    const startRow = 5 + nonEmptyCount;
                    const endRow = startRow + rows.length - 1;

                    await callSheetsApi(
                        spreadsheetId,
                        accessToken,
                        `/values/${encodeURIComponent(resolvedSheetName)}!${rangePrefix}${startRow}:${rangeSuffix}${endRow}?valueInputOption=RAW`,
                        'PUT',
                        {
                            values: rows
                        }
                    );
                }
            }

            const beforeData = reportDoc.data();
            const updatedData = {
                sheetsSynced: true,
                isSentToSheets: true,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            await reportRef.set(updatedData, { merge: true });

            await writeAuditLog({
                actorUid: uid,
                action: 'report.sheets_sync',
                entityType: 'report',
                entityId: reportId,
                before: beforeData ?? null,
                after: updatedData,
            });

            return { success: true };
        } catch (error: any) {
            if (error instanceof functions.https.HttpsError) {
                throw error;
            }
            throw new functions.https.HttpsError('failed-precondition', error.message || 'Unknown error occurred.');
        }
    },
);
