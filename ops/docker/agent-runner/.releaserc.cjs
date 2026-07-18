const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'agent-runner-v${version}',
};
