const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'vikunja-mcp-v${version}',
};
