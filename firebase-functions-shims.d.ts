/**
 * Shims for firebase-functions and firebase-admin to resolve IDE errors
 * when node_modules are not present in the root directory.
 */

declare module 'firebase-functions' {
    export namespace https {
        export interface CallableContext {
            auth?: {
                uid: string;
                token: {
                    role?: string;
                    [key: string]: any;
                };
            };
            rawRequest: any;
        }

        export class HttpsError extends Error {
            constructor(code: string, message: string, details?: any);
        }

        export function onCall<T = any, R = any>(
            handler: (data: T, context: CallableContext) => Promise<R> | R
        ): any;
    }

    export namespace auth {
        export interface UserRecord {
            uid: string;
            email?: string;
            displayName?: string;
            photoURL?: string;
            disabled: boolean;
            metadata: any;
            providerData: any[];
            customClaims?: any;
        }

        export function user(): {
            onCreate(handler: (user: UserRecord, context: any) => Promise<void> | void): any;
            onDelete(handler: (user: UserRecord, context: any) => Promise<void> | void): any;
        };
    }

    export const config: () => any;
}

declare module 'firebase-admin' {
    export function initializeApp(options?: any, name?: string): any;

    export function auth(): {
        setCustomUserClaims(uid: string, claims: object | null): Promise<void>;
        getUser(uid: string): Promise<any>;
    };

    export function firestore(): firestore.Firestore;

    export namespace firestore {
        export interface Firestore {
            collection(path: string): CollectionReference;
            doc(path: string): DocumentReference;
            batch(): WriteBatch;
        }

        export interface Query {
            where(fieldPath: string, opStr: string, value: any): Query;
            orderBy(fieldPath: string, directionStr?: 'asc' | 'desc'): Query;
            limit(limit: number): Query;
            startAfter(snapshot: any): Query;
            get(): Promise<{ docs: any[]; empty: boolean; size: number }>;
        }

        export interface CollectionReference extends Query {
            doc(path?: string): DocumentReference;
            add(data: any): Promise<DocumentReference>;
        }

        export interface DocumentReference {
            id: string;
            set(data: any, options?: { merge?: boolean }): Promise<any>;
            update(data: any): Promise<any>;
            delete(): Promise<any>;
            get(): Promise<any>;
        }

        export interface WriteBatch {
            set(ref: DocumentReference, data: any, options?: { merge?: boolean }): WriteBatch;
            update(ref: DocumentReference, data: any): WriteBatch;
            delete(ref: DocumentReference): WriteBatch;
            commit(): Promise<any>;
        }

        export class FieldValue {
            static serverTimestamp(): any;
            static delete(): any;
        }
    }
}
