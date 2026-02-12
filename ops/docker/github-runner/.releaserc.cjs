const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'github-runner-v${version}',
};
