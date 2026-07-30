import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { hvigor } from '@ohos/hvigor';
import * as fs from 'fs';
import * as path from 'path';

hvigor.getRootNode().afterNodeEvaluate(node => {
  const signingPath = path.resolve(node.getNodePath(), 'signing.local.json');
  if (!fs.existsSync(signingPath)) {
    return;
  }

  const signingConfigs = JSON.parse(fs.readFileSync(signingPath, 'utf8'));
  if (!Array.isArray(signingConfigs)) {
    throw new Error(`${signingPath} must contain a JSON array`);
  }

  const appContext = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
  const buildProfile = appContext.getBuildProfileOpt();
  buildProfile.app.signingConfigs = signingConfigs;
  appContext.setBuildProfileOpt(buildProfile);
});

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
