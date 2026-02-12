const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'helm-deploy-v${version}',
};
