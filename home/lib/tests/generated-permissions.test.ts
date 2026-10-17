import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    compileRules,
    deniedCommandPart,
} from "../../../configs/pi/extensions/agent-modes/permission-rules";

// Input is produced by generated-permissions.nix. No commands in this corpus
// execute: they are strings passed to the actual Pi runtime matcher.
const generated = JSON.parse(readFileSync(process.argv[2], "utf8"));
const openCodeMatcher = process.env.OPENCODE_WILDCARD_MODULE
    ? await import(process.env.OPENCODE_WILDCARD_MODULE)
    : null;
let checked = 0;
for (const [variant, targets] of Object.entries(generated) as [string, any][]) {
    for (const target of ["pi", "opencode"]) {
        const config = JSON.parse(targets[target]);
        function decision(mode: string, command: string) {
            const permission = config.agent[mode].permission;
            if (target === "pi") {
                return (
                    deniedCommandPart(command, compileRules({ permission }))
                        ?.action ?? "allow"
                );
            }
            if (!openCodeMatcher) return null;
            // OpenCode v1.18.34 permission.evaluate uses the last matching rule.
            // Use the pinned upstream core wildcard implementation, not a
            // guessed text-glob equivalent. This does not execute its full agent.
            return (
                Object.entries(permission.bash).findLast(([pattern]) =>
                    openCodeMatcher.match(command, pattern),
                )?.[1] ?? "ask"
            );
        }
        function expect(mode: string, command: string, expected: string) {
            const actual = decision(mode, command);
            if (actual === null) return;
            assert.equal(
                actual,
                expected,
                `${variant}/${target}/${mode}: ${command}`,
            );
            checked++;
        }
        for (const command of [
            "git status",
            "git --no-pager status",
            "git stash list",
            "git stash show",
            "git branch --list",
            "git config --get user.name",
        ]) {
            expect("plan", command, "allow");
            expect("build", command, "allow");
        }
        for (const command of [
            "git branch -D SYNTHETIC",
            "git config --global user.name SYNTHETIC",
            "git -C /tmp push",
            "git -c alias.status=push status",
            "git -C push status",
            "git config --get-all-unsafe user.name",
        ]) {
            expect("plan", command, "deny");
        }
        if (variant !== "yolo") {
            for (const command of [
                "git push --force",
                "git -C /tmp push origin main --force",
                "git -c key=value push --force",
                "env git push --force",
                "command git push --force",
                "exec git push --force",
                "/usr/bin/git push --force",
            ]) {
                expect("build", command, "deny");
            }
        }
        if (variant === "restricted") {
            for (const command of [
                "git push",
                "git -C /tmp push",
                "git -c key=value push",
                "env git push",
                "command git push",
                "exec git push",
                "/usr/bin/git push",
                "git stash",
                "git -C /tmp stash",
                "git stash -u",
                "git stash drop",
                "git stash push",
            ]) {
                expect("build", command, "deny");
            }
        } else {
            expect("build", "git push origin main", "allow");
        }
        if (variant === "yolo") expect("build", "git push --force", "allow");
    }
}
console.log(
    `${checked} generated-policy behavioral checks passed (Pi runtime${openCodeMatcher ? "; pinned OpenCode wildcard + last-match evaluation" : "; OpenCode NOT checked"}).`,
);
