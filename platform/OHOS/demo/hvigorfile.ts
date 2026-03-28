import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import { syncSharedResources } from './syncSharedResPlugin';

syncSharedResources(__dirname);

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
