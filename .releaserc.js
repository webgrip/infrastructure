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
    successCmd: 'echo "version=${nextRelease.version}" >> $GITHUB_OUTPUT',
  },
];

const plugins = [
  commitAnalyzerConfig,
  releaseNotesGeneratorConfig,
  execConfig,
  '@semantic-release/github',
];

module.exports = {
  extends: 'semantic-release-monorepo',
  branches,
  plugins,
};
