import type { ProviderId } from "../routes";
import { anthropicAdapter } from "./anthropic";
import { geminiAdapter } from "./gemini";
import { openaiAdapter, workersAIAdapter, xaiAdapter } from "./openai";
import type { ChatAdapter } from "./types";

export const ADAPTERS: Readonly<Record<ProviderId, ChatAdapter>> = {
  openai: openaiAdapter,
  gemini: geminiAdapter,
  anthropic: anthropicAdapter,
  workersai: workersAIAdapter,
  xai: xaiAdapter,
};
