declare const Deno: {
  env: {
    get(name: string): string | undefined;
  };
  serve(
    handler: (request: Request) => Response | Promise<Response>,
  ): unknown;
};

declare module "std/http/server.ts" {
  export function serve(handler: (request: Request) => Response | Promise<Response>): void;
}
