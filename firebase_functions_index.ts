/// <reference path="./firebase-functions-shims.d.ts" />

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const ALLOWED_ROLES = new Set(['employee', 'manager', 'admin']);

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

function assertAdmin(context: functions.https.CallableContext): void {
    if (context.auth?.token?.role !== 'admin') {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only admins can perform this action.',
        );
    }
}

export const setUserRole = functions.https.onCall<SetUserRoleRequest, SetUserRoleResponse>(
    async (data: SetUserRoleRequest, context: functions.https.CallableContext) => {
        assertAdmin(context);

        const uid = String(data?.uid ?? '');
        const role = String(data?.role ?? '').toLowerCase();

        if (!uid || !ALLOWED_ROLES.has(role)) {
            throw new functions.https.HttpsError('invalid-argument', 'Invalid uid or role.');
        }

        const validatedRole = role as AppRole;

        await admin.auth().setCustomUserClaims(uid, { role: validatedRole });
        await admin.firestore().collection('users').doc(uid).set(
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
        await admin.firestore().collection('users').doc(user.uid).set(
            {
                email: user.email ?? null,
                displayName: user.displayName ?? null,
                role: 'employee',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
        );
    },
);