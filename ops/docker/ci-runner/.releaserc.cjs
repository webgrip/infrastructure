const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'ci-runner-v${version}',
};
