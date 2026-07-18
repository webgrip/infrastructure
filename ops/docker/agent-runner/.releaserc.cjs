const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'openhands-runner-v${version}',
};
