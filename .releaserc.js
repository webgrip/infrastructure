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

// The verifyRelease step proves the image still builds before we cut a tag. A plain
// `docker build` is uncached on the ephemeral runner, so it rebuilds the whole image (heavy
// `apk add`s, multiple base images) on every run — minutes per release. When the monorepo
// action exports BUILD_CACHE_REF (the `<registry>/<owner>/<image>:cache` ref the publish path's
// docker-build-push-registry writes via buildx, mode=max), read from it: a commit that doesn't
// touch the Dockerfile becomes a full cache hit (seconds). We deliberately do NOT cache-to it —
// this gate is amd64-only while publish builds amd64+arm64 into the same ref, so writing here
// would clobber the arm64 layers publish relies on. The cache is populated solely by publish, so
// verify reads "one release behind", which is a full hit for the common no-Dockerfile-change bump.
// `--output=type=cacheonly` builds every stage and discards the result (it's only a gate). Falls
// back to a plain build when the env var is unset (e.g. a GitHub run that hasn't opted in).
const cacheRef = process.env.BUILD_CACHE_REF;
const verifyReleaseCmd = cacheRef
    ? [
        'docker buildx build --file Dockerfile --platform linux/amd64',
        `--cache-from type=registry,ref=${cacheRef}`,
        '--output=type=cacheonly .',
    ].join(' ')
    : 'docker build --file Dockerfile .';

const execConfig = [
    '@semantic-release/exec',
    {
        verifyReleaseCmd,
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
