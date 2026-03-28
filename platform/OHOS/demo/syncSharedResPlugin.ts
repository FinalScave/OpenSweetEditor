import * as fs from 'fs';
import * as path from 'path';

function removeDir(targetDir: string): void {
  if (!fs.existsSync(targetDir)) {
    return;
  }
  for (const entry of fs.readdirSync(targetDir, { withFileTypes: true })) {
    const fullPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      removeDir(fullPath);
    } else {
      fs.unlinkSync(fullPath);
    }
  }
  fs.rmdirSync(targetDir);
}

function copyDir(sourceDir: string, targetDir: string): void {
  fs.mkdirSync(targetDir, { recursive: true });
  for (const entry of fs.readdirSync(sourceDir, { withFileTypes: true })) {
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      copyDir(sourcePath, targetPath);
    } else {
      fs.copyFileSync(sourcePath, targetPath);
    }
  }
}

export function syncSharedResources(modulePath: string): void {
  const sourceDir = path.resolve(modulePath, '..', '..', '_res');
  const legacyTargetDir = path.resolve(modulePath, 'src', 'main', 'resources', 'base', 'rawfile');
  const targetDir = path.resolve(modulePath, 'src', 'main', 'resources', 'rawfile', 'demo_shared');
  if (!fs.existsSync(sourceDir)) {
    return;
  }
  removeDir(legacyTargetDir);
  removeDir(targetDir);
  copyDir(sourceDir, targetDir);
}
