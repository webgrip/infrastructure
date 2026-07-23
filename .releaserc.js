const noteKeywords = ['BREAKING CHANGE', 'BREAKING CHANGES', 'BREAKING'];

// The pinned conventionalcommits preset (7.0.2) ships a header regex that accepts neither a
// comma in the scope nor the `!` breaking marker: `feat(a,b): x` and `feat!: x` parse as
// type-less and release NOTHING — silently. That dropped rust-ci-runner's helm/sccache feat
// (e0e1c82: scope `ci-runner,rust-ci-runner`) without a trace. Override both patterns:
// any characters allowed inside the scope parens, optional `!` (which escalates to major).
// Verified against @semantic-release/commit-analyzer@13.0.0 + preset 7.0.2 — remove these
// overrides only when the preset is bumped to a version whose defaults pass the same matrix.
const parserOpts = {
    noteKeywords,
    headerPattern: /^(\w*)(?:\(([^)]*)\))?!?: (.+)$/,
    breakingHeaderPattern: /^(\w*)(?:\(([^)]*)\))?!: (.+)$/,
};

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
        parserOpts,
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
        parserOpts,
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
// The cached (in-cluster) verify build pulls base images through the Harbor proxy too — the
// Dockerfiles default REGISTRY_* to docker.io/ghcr, so override them here to match the publish
// build. Only the cached branch (Forgejo, BUILD_CACHE_REF set) does this; the plain `docker build`
// fallback (GitHub) keeps the upstream defaults, since it can't reach LAN-only Harbor.
const harborBaseArgs = [
    '--build-arg REGISTRY_DOCKERHUB=harbor.webgrip.dev/dockerhub',
    '--build-arg REGISTRY_GHCR=harbor.webgrip.dev/ghcr',
    '--build-arg REGISTRY_MCR=harbor.webgrip.dev/mcr',
];
const cacheRef = process.env.BUILD_CACHE_REF;
const verifyReleaseCmd = cacheRef
    ? [
        'docker buildx build --file Dockerfile --platform linux/amd64',
        ...harborBaseArgs,
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

// Version bump (package.json) + commit-back, but ONLY on the leading Forgejo side
// (SEMANTIC_RELEASE_GITEA). GitHub is now a pure mirror that cuts no releases, so it must never
// re-version or commit — that's what kept the two sequences from diverging. The `[skip ci]` message
// is honoured by both Forgejo and GitHub, so the mirror push of this commit re-triggers nothing.
const commitBackPlugins = process.env.SEMANTIC_RELEASE_GITEA
    ? [
        ['@semantic-release/npm', { npmPublish: false }],
        ['@semantic-release/git', {
            assets: ['package.json'],
            message: 'chore(release): ${nextRelease.gitTag} [skip ci]\n\n${nextRelease.notes}',
        }],
    ]
    : [];

const plugins = [
    commitAnalyzerConfig,
    releaseNotesGeneratorConfig,
    execConfig,
    ...commitBackPlugins,
    publishPlugin,
];

module.exports = {
    extends: 'semantic-release-monorepo',
    branches,
    plugins,
};
