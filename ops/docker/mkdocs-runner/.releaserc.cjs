const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'mkdocs-runner-v${version}',
};
