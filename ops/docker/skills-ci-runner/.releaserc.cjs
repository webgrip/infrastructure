const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'skills-ci-runner-v${version}',
};
