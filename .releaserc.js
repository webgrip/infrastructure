const noteKeywords = ['BREAKING CHANGE', 'BREAKING CHANGES', 'BREAKING'];

const branches = [
    'main',
    {
        name: 'release/*',
        prerelease: 'rc',
    },
];

const commitAnalyzerConfig = [
    '@semantic-release/commit-analyzer',
    {
        preset: 'conventionalcommits',
        releaseRules: [
            { type: 'feature', release: 'minor' },
            { type: 'bugfix', release: 'patch' },
            { type: 'hotfix', release: 'patch' },
        ],
        parserOpts: { noteKeywords },
    },
];

const releaseNotesGeneratorConfig = [
    '@semantic-release/release-notes-generator',
    {
        preset: 'conventionalcommits',
        presetConfig: {
            types: [
                { type: 'feat', section: 'Added' },
                { type: 'feature', section: 'Added' },
                { type: 'fix', section: 'Fixed' },
                { type: 'bugfix', section: 'Fixed' },
                { type: 'hotfix', section: 'Fixed' },
                { type: 'perf', section: 'Performance' },
                { type: 'refactor', section: 'Changed' },
                { type: 'chore', section: 'Internal', hidden: true },
                { type: 'docs', section: 'Docs', hidden: false },
                { type: 'test', section: 'Tests', hidden: false },
            ],
        },
        parserOpts: { noteKeywords },
    },
];

const execConfig = [
    '@semantic-release/exec',
    {
        verifyReleaseCmd: 'docker build --file Dockerfile .',
        successCmd: 'echo "version=${nextRelease.version}" >> $GITHUB_OUTPUT',
    },
];

// Forgejo CI sets GITEA_URL (consumed by @saithodev/semantic-release-gitea); publish via the
// Gitea/Forgejo API there. GitHub CI leaves GITEA_URL unset, so publish via @semantic-release/github.
// Forgejo has no GitHub GraphQL endpoint, so @semantic-release/github's success step 404s on
// POST /api/v1/graphql (getAssociatedPRs) — hence the env-gated plugin instead of one frozen config.
const publishPlugin = process.env.GITEA_URL
    ? '@saithodev/semantic-release-gitea'
    : '@semantic-release/github';

const plugins = [
    commitAnalyzerConfig,
    releaseNotesGeneratorConfig,
    execConfig,
    publishPlugin,
];

module.exports = {
    extends: 'semantic-release-monorepo',
    branches,
    plugins,
};
