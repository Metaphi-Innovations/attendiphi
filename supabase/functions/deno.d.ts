// Ambient type definitions for Deno runtime globals in Supabase Edge Functions.
// Used by IDE TypeScript Language Server to prevent false syntax warnings.

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
