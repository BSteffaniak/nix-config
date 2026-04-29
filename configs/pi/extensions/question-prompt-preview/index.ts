import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, wrapTextWithAnsi } from "@mariozechner/pi-tui";

const WIDGET_KEY = "question-prompt-preview";
const PROMPT_LINE_THRESHOLD = 7;
const ESTIMATED_WRAP_WIDTH = 100;

interface QuestionLike {
    questionTopic?: string;
    prompt?: string;
}

interface PromptPreview {
    index: number;
    topic: string;
    prompt: string;
    estimatedLines: number;
}

function estimateWrappedLines(text: string): number {
    return text.split(/\r?\n/).reduce((count, line) => {
        return (
            count + Math.max(1, Math.ceil(line.length / ESTIMATED_WRAP_WIDTH))
        );
    }, 0);
}

function getLongPromptPreviews(input: unknown): PromptPreview[] {
    const questions = (input as { questions?: QuestionLike[] } | undefined)
        ?.questions;
    if (!Array.isArray(questions)) return [];

    return questions.flatMap((question, index) => {
        const prompt = question?.prompt;
        if (typeof prompt !== "string" || prompt.trim() === "") return [];

        const estimatedLines = estimateWrappedLines(prompt);
        if (estimatedLines <= PROMPT_LINE_THRESHOLD) return [];

        return [
            {
                index,
                topic: question.questionTopic || `Question ${index + 1}`,
                prompt,
                estimatedLines,
            },
        ];
    });
}

function stylePromptLine(line: string, theme: any): string {
    if (/^\+/.test(line) && !/^\+\+\+/.test(line))
        return theme.fg("toolDiffAdded", line);
    if (/^-/.test(line) && !/^---/.test(line))
        return theme.fg("toolDiffRemoved", line);
    if (/^@@/.test(line)) return theme.fg("accent", line);
    if (/^(diff --git|index |--- |\+\+\+ )/.test(line))
        return theme.fg("dim", line);
    if (/^```/.test(line)) return theme.fg("mdCodeBlockBorder", line);
    return theme.fg("text", line);
}

function addWrapped(
    lines: string[],
    text: string,
    width: number,
    style: (s: string) => string,
): void {
    const wrapped = wrapTextWithAnsi(style(text), Math.max(1, width));
    if (wrapped.length === 0) {
        lines.push("");
        return;
    }
    for (const line of wrapped) {
        lines.push(truncateToWidth(line, width));
    }
}

function renderPromptPreview(
    previews: PromptPreview[],
    width: number,
    theme: any,
): string[] {
    const lines: string[] = [];
    const safeWidth = Math.max(20, width);
    const border = theme.fg("accent", "─".repeat(safeWidth));

    lines.push(border);
    addWrapped(
        lines,
        previews.length === 1
            ? "Full question prompt"
            : "Full question prompts",
        safeWidth,
        (s) => theme.fg("accent", theme.bold(s)),
    );
    addWrapped(
        lines,
        "Shown because the upstream question UI truncates long prompts. Answer in the question UI below as usual.",
        safeWidth,
        (s) => theme.fg("dim", s),
    );
    lines.push("");

    for (let i = 0; i < previews.length; i++) {
        const preview = previews[i];
        if (!preview) continue;

        if (i > 0) lines.push("");
        addWrapped(
            lines,
            `Question ${preview.index + 1}: ${preview.topic} (${preview.estimatedLines} estimated lines)`,
            safeWidth,
            (s) => theme.fg("accent", theme.bold(s)),
        );
        lines.push("");

        for (const rawLine of preview.prompt.split(/\r?\n/)) {
            if (rawLine === "") {
                lines.push("");
                continue;
            }
            addWrapped(lines, rawLine, safeWidth, (s) =>
                stylePromptLine(s, theme),
            );
        }
    }

    lines.push("");
    lines.push(border);
    return lines.map((line) => truncateToWidth(line, safeWidth));
}

export default function questionPromptPreview(pi: ExtensionAPI) {
    const activePreviewToolCalls = new Set<string>();

    pi.on("tool_call", async (event, ctx) => {
        if (event.toolName !== "question" || !ctx.hasUI) return;

        const previews = getLongPromptPreviews(event.input);
        if (previews.length === 0) return;

        activePreviewToolCalls.add(event.toolCallId);
        ctx.ui.setWidget(
            WIDGET_KEY,
            (_tui, theme) => ({
                render: (width: number) =>
                    renderPromptPreview(previews, width, theme),
                invalidate: () => {},
            }),
            { placement: "aboveEditor" },
        );
    });

    pi.on("tool_result", async (event, ctx) => {
        if (event.toolName !== "question") return;

        activePreviewToolCalls.delete(event.toolCallId);
        if (activePreviewToolCalls.size === 0) {
            ctx.ui.setWidget(WIDGET_KEY, undefined);
        }
    });
}
