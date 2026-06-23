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

// The Forgejo action sets SEMANTIC_RELEASE_GITEA=true (a literal, so it's reliably present — unlike
// a vars.* lookup) → publish via the Gitea/Forgejo API. GitHub CI leaves it unset → @semantic-release/github.
// Forgejo has no GitHub GraphQL endpoint, so @semantic-release/github's success step 404s on
// POST /api/v1/graphql (getAssociatedPRs) — hence the env-gated plugin instead of one frozen config.
const publishPlugin = process.env.SEMANTIC_RELEASE_GITEA
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
