// extension.ts — VS Code activation point for the Inka LSP client.
//
// This package is one peer transport per CLAUDE.md anchor: "every
// transport is a handler." `inka edit` (the canonical browser-
// holographic-live IDE per IE walkthrough commit b9cf011) is the
// canonical projection. This extension is the LSP-peer-transport
// bridge for developers who use VS Code or VS Code-derivative
// editors (Cursor, Windsurf, etc.).
//
// What this file does: spawn `inka lsp` as a child process; connect
// to it over stdio via vscode-languageclient. The wheel hosts the
// LSP transport handler at src/mentl_lsp.nx (commit ff0d2e3); the
// `inka lsp` subcommand at src/main.nx (commit 1fce2a2) wires it
// through the full Mentl handler chain (mentl_voice_filesystem +
// mentl_voice_default + graph + Interact). When VS Code talks to
// `inka lsp`, every LSP request reaches Mentl through her installed
// handler chain; every response is her voice projected through the
// LSP transport.

import { workspace, ExtensionContext, window, OutputChannel } from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind,
} from "vscode-languageclient/node";

let client: LanguageClient | undefined;
let outputChannel: OutputChannel | undefined;

export function activate(context: ExtensionContext): void {
  outputChannel = window.createOutputChannel("Inka Language Server");
  context.subscriptions.push(outputChannel);

  const config = workspace.getConfiguration("inka");
  const serverPath = config.get<string>("serverPath", "inka");
  const serverArgs = config.get<string[]>("serverArgs", ["lsp"]);

  const serverOptions: ServerOptions = {
    run: {
      command: serverPath,
      args: serverArgs,
      transport: TransportKind.stdio,
    },
    debug: {
      command: serverPath,
      args: serverArgs,
      transport: TransportKind.stdio,
    },
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: "file", language: "inka" }],
    synchronize: {
      fileEvents: workspace.createFileSystemWatcher("**/*.nx"),
    },
    outputChannel,
    traceOutputChannel: outputChannel,
  };

  client = new LanguageClient(
    "inka",
    "Inka Language Server",
    serverOptions,
    clientOptions,
  );

  outputChannel.appendLine(
    `Starting Inka LSP client → spawning: ${serverPath} ${serverArgs.join(" ")}`,
  );

  client.start().catch((err: unknown) => {
    const msg = err instanceof Error ? err.message : String(err);
    window.showErrorMessage(
      `Failed to start Inka LSP. Is \`${serverPath}\` on your PATH? ` +
        `If you have not yet built the Inka wheel (first-light-L1), ` +
        `the binary will not exist yet. Error: ${msg}`,
    );
    outputChannel?.appendLine(`Inka LSP start failed: ${msg}`);
  });

  context.subscriptions.push({
    dispose: () => {
      client?.stop();
    },
  });
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
