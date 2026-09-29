// Ambient type definitions for Deno runtime globals and remote dependencies in Supabase Edge Functions.
// Used by IDE TypeScript Language Server to prevent false syntax warnings when Deno LSP is inactive.

declare namespace Deno {
  export interface ServeOptions {
    port?: number;
    hostname?: string;
  }
  export function serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
  export const env: {
    get(key: string): string | undefined;
  };
}

declare module "jose" {
  export type JWTPayload = Record<string, unknown> & {
    iss?: string;
    sub?: string;
    aud?: string | string[];
    jti?: string;
    nbf?: number;
    exp?: number;
    iat?: number;
    user_id?: string;
    [key: string]: unknown;
  };

  export function jwtVerify(
    jwt: string | Uint8Array,
    key: unknown,
    options?: {
      issuer?: string | string[];
      audience?: string | string[];
      [key: string]: unknown;
    },
  ): Promise<{ payload: JWTPayload; protectedHeader: Record<string, unknown> }>;

  export function createRemoteJWKSet(
    url: URL,
    options?: Record<string, unknown>,
  ): (protectedHeader?: unknown, token?: unknown) => Promise<unknown>;

  export class SignJWT {
    constructor(payload: JWTPayload);
    setProtectedHeader(protectedHeader: { alg: string; [key: string]: unknown }): this;
    setIssuedAt(input?: number | string | Date): this;
    setIssuer(issuer: string): this;
    setSubject(subject: string): this;
    setAudience(audience: string | string[]): this;
    setJti(jwtId: string): this;
    setNotBefore(input: number | string | Date): this;
    setExpirationTime(input: number | string | Date): this;
    sign(key: unknown, options?: Record<string, unknown>): Promise<string>;
    [key: string]: any;
  }

  export function importPKCS8(
    pkcs8: string,
    alg: string,
    options?: Record<string, unknown>,
  ): Promise<unknown>;
}

declare module "denomailer" {
  export interface SendConfig {
    from: string;
    to: string | string[];
    subject: string;
    content: string;
    html?: string;
    [key: string]: unknown;
  }

  export class SMTPClient {
    constructor(options: {
      connection: {
        hostname: string;
        port: number;
        tls: boolean;
        auth: {
          username: string;
          password: string;
        };
      };
    });
    send(config: SendConfig): Promise<unknown>;
    close(): Promise<void>;
  }
}
