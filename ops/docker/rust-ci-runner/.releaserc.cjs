const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'rust-ci-runner-v${version}',
};
