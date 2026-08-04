import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '@ohos/flutter_module';
import {
  MethodChannel,
  MethodCallHandler,
  MethodResult,
  StandardMethodCodec,
  MethodCall,
} from '@ohos/flutter_ohos';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { cameraPicker } from '@kit.CameraKit';
import { fileIo } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { common, Want, AbilityConstant, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import pasteboard from '@ohos.pasteboard';
import { BusinessError } from '@ohos.base';

// Legacy — kept for Index.ets PickerDialog (currently unused)
export function resolvePickerResult(paths: string[]): void {
  console.info(TAG, 'resolvePickerResult (legacy stub): ' + JSON.stringify(paths));
}

const TAG = 'EntryAbility';


class SaveImgHandler implements MethodCallHandler {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'savePictureToAlbum': {
        const path = call.argument('path') as string;
        this.saveToAlbum(path, result);
        break;
      }
      case 'takePhoto':
        this.takePhoto(result);
        break;
      case 'pickImages':
        this.pickImages(result);
        break;
      case 'getClipboardText':
        this.getClipboardText(result);
        break;
      case 'copyToClipboard':
        this.copyToClipboard('' + call['argument'], result);
        break;
      case 'openWebView':
        this.openWebView('' + call['argument'], result);
        break;
      case 'openInBrowser':
        this.openInBrowser('' + call['argument'], result);
        break;
      case 'flutterFirstFrame':
        AppStorage.Set<boolean>('flutterFirstFrame', true);
        result.success(true);
        break;
      default:
        result.notImplemented();
    }
  }

  private async takePhoto(result: MethodResult) {
    console.info(TAG, 'takePhoto entered');
    try {
      const profile = new cameraPicker.PickerProfile();
      profile.cameraPosition = 1; // REAR camera
      const resultData = await cameraPicker.pick(
        this.context,
        [cameraPicker.PickerMediaType.PHOTO],
        profile
      );
      console.info(TAG, 'takePhoto: resultUri=' + resultData.resultUri + ' resultCode=' + resultData.resultCode);

      if (resultData.resultUri && resultData.resultUri.length > 0) {
        // Copy to cache dir
        const cacheDir = this.context.cacheDir + '/picker_temp';
        try { fs.mkdirSync(cacheDir); } catch (e) {}
        const srcUri = resultData.resultUri;
        const ext = srcUri.split('.').pop() || 'jpg';
        const destPath = cacheDir + '/camera_' + Date.now() + '.' + ext;
        const srcFile = fs.openSync(srcUri);
        const destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
        fs.copyFileSync(srcFile.fd, destFile.fd);
        fs.closeSync(srcFile);
        fs.closeSync(destFile);
        console.info(TAG, 'takePhoto: copied to ' + destPath);
        result.success(destPath);
      } else {
        console.warn(TAG, 'takePhoto: user cancelled or no result');
        result.success(null);
      }
    } catch (e) {
      console.error(TAG, 'takePhoto failed: ' + JSON.stringify(e));
      result.success(null);
    }
  }

  private async pickImages(result: MethodResult) {
    console.info(TAG, 'pickImages entered');
    try {
      console.info(TAG, 'pickImages: creating PhotoViewPicker');
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      console.info(TAG, 'pickImages: PhotoViewPicker created, calling select');
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 3;
      console.info(TAG, 'pickImages: select completed');
      const res = await photoPicker.select(options);
      console.info(TAG, 'pickImages: select returned, uris length: ' + (res.photoUris ? res.photoUris.length : 0));
      const uris = res.photoUris;

      if (!uris || uris.length === 0) {
        result.success([]);
        return;
      }

      // Copy selected photos to cache dir
      const cacheDir = this.context.cacheDir + '/picker_temp';
      try {
        fs.mkdirSync(cacheDir);
      } catch (e) {
        // dir already exists, ignore
      }

      const resultPaths: string[] = [];
      for (let i = 0; i < uris.length; i++) {
        try {
          const srcUri = uris[i];
          const ext = srcUri.split('.').pop() || 'jpg';
          const destPath = cacheDir + '/img_' + i + '.' + ext;
          const srcFile = fs.openSync(srcUri);
          const destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
          fs.copyFileSync(srcFile.fd, destFile.fd);
          fs.closeSync(srcFile);
          fs.closeSync(destFile);
          resultPaths.push(destPath);
        } catch (e) {
          console.warn(TAG, 'copy picker file failed: ' + JSON.stringify(e));
        }
      }

      result.success(resultPaths);
    } catch (e) {
      console.error(TAG, 'PhotoViewPicker select failed: ' + JSON.stringify(e));
      console.error(TAG, 'PhotoViewPicker error code: ' + (e as BusinessError).code);
      console.error(TAG, 'PhotoViewPicker error message: ' + (e as BusinessError).message);
      result.success([]);
    }
  }

  private getClipboardText(result: MethodResult): void {
    console.info(TAG, 'getClipboardText called');
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Permissions[] = ['ohos.permission.READ_PASTEBOARD'];
      atManager.requestPermissionsFromUser(this.context, permissions).then((data) => {
        const grantStatus: number[] = data.authResults;
        if (grantStatus.length > 0 && grantStatus[0] === 0) {
          console.info(TAG, 'clipboard permission granted');
          this.readPasteboard(result);
        } else {
          console.warn(TAG, 'clipboard permission denied by user');
          result.success(null);
        }
      }).catch((err: BusinessError) => {
        console.warn(TAG, 'requestPermissionsFromUser failed: ' + JSON.stringify(err));
        result.success(null);
      });
    } catch (e) {
      console.warn(TAG, 'getClipboardText failed: ' + JSON.stringify(e));
      result.success(null);
    }
  }

  private async readPasteboard(result: MethodResult): Promise<void> {
    try {
      const pb = pasteboard.getSystemPasteboard();
      const data = await pb.getData();
      const recordCount = data.getRecordCount();
      console.info(TAG, 'readPasteboard recordCount: ' + recordCount);
      // Read all text records and concatenate
      let fullText = data.getPrimaryText() || '';
      for (let i = 0; i < recordCount; i++) {
        try {
          const record = data.getRecordAt(i);
          if (record) {
            const txt = await record.convertToText();
            if (txt && txt.length > 0 && !fullText.includes(txt)) {
              fullText += (fullText.length > 0 ? '\n' : '') + txt;
            }
          }
        } catch (riErr) {
          console.warn(TAG, 'record ' + i + ' convert failed: ' + JSON.stringify(riErr));
        }
      }
      console.info(TAG, 'readPasteboard full len=' + fullText.length + ' preview=' + fullText.substring(0, 300));
      result.success(fullText.length > 0 ? fullText : null);
    } catch (e) {
      console.warn(TAG, 'readPasteboard failed: ' + JSON.stringify(e));
      result.success(null);
    }
  }

  private copyToClipboard(text: string, result: MethodResult): void {
    try {
      const pb = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData({ mimeType: pasteboard.MIMETYPE_TEXT_PLAIN, value: text });
      pb.setData(data);
      result.success(true);
    } catch (e) {
      console.warn(TAG, 'copyToClipboard failed: ' + JSON.stringify(e));
      result.success(false);
    }
  }

  private async openInBrowser(url: string, result: MethodResult): Promise<void> {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        console.info(TAG, 'openInBrowser: url=' + url);
        // Wrap in new microtask to ensure UI thread dispatch
        await new Promise<void>((resolve) => {
          setTimeout(async () => {
            try {
              await this.context.openLink(url, { appLinkingOnly: false });
              console.info(TAG, 'openInBrowser: openLink succeeded');
              result.success(true);
            } catch (e) {
              console.warn(TAG, 'openLink failed: ' + JSON.stringify(e));
              try {
                await this.context.startAbility({
                  bundleName: 'com.huawei.hmos.browser',
                  uri: url,
                });
                console.info(TAG, 'openInBrowser: Huawei Browser succeeded');
                result.success(true);
              } catch (e2) {
                console.error(TAG, 'Huawei Browser also failed: ' + JSON.stringify(e2));
                result.success(false);
              }
            }
            resolve();
          }, 0);
        });
      } else {
        result.success(false);
      }
    } catch (e) {
      console.warn(TAG, 'openInBrowser failed: ' + JSON.stringify(e));
      result.success(false);
    }
  }

  private async openWebView(url: string, result: MethodResult): Promise<void> {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        console.info(TAG, 'openWebView: url=' + url);
        // Use AppStorage (polled by Index.ets)
        AppStorage.Set<string>('webViewUrl', url);
        AppStorage.Set<boolean>('webViewPending', true);
        console.info(TAG, 'openWebView: set AppStorage signals');
        result.success(true);
      } else {
        result.success(false);
      }
    } catch (e) {
      console.warn(TAG, 'openWebView failed: ' + JSON.stringify(e));
      result.success(false);
    }
  }

  private async saveToAlbum(path: string, result: MethodResult) {
    // Try #1: showAssetsCreationDialog — shows system dialog, no permission needed
    try {
      const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const srcFileUri = path;
      const ext = path.split('.').pop() || 'png';

      const photoCreationConfigs: photoAccessHelper.PhotoCreationConfig[] = [
        {
          title: '',
          fileNameExtension: ext,
          photoType: photoAccessHelper.PhotoType.IMAGE,
          subtype: photoAccessHelper.PhotoSubtype.DEFAULT,
        },
      ];

      console.info(TAG, 'showAssetsCreationDialog for: ' + srcFileUri);
      const desFileUris: string[] = await helper.showAssetsCreationDialog(
        [srcFileUri], photoCreationConfigs
      );

      if (desFileUris && desFileUris.length > 0) {
        // Copy content from source to destination
        const desFile = await fileIo.open(desFileUris[0], fileIo.OpenMode.WRITE_ONLY);
        const srcFile = await fileIo.open(srcFileUri, fileIo.OpenMode.READ_ONLY);
        await fileIo.copyFile(srcFile.fd, desFile.fd);
        await fileIo.close(srcFile);
        await fileIo.close(desFile);
        console.info(TAG, 'showAssetsCreationDialog success, uri: ' + desFileUris[0]);
        result.success({ saved: true, album: true });
        return;
      }
    } catch (e) {
      console.warn(TAG, 'showAssetsCreationDialog failed: ' + JSON.stringify(e));
    }

    // Try #2: Fallback to app internal files dir (always works)
    try {
      const fileName = path.split('/').pop() || 'temp.png';
      const dstDir = this.context.filesDir + '/微北洋';
      await fileIo.mkdir(dstDir, true);
      const dstPath = dstDir + '/' + fileName;
      const srcFile = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
      const dstFile = await fileIo.open(dstPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      await fileIo.copyFile(srcFile.fd, dstFile.fd);
      await fileIo.close(srcFile);
      await fileIo.close(dstFile);
      console.info(TAG, 'saved to internal files: ' + dstPath);
      result.success({ saved: true, album: false });
    } catch (e) {
      console.error(TAG, 'all save paths failed: ' + JSON.stringify(e));
      result.success({ saved: false, album: false });
    }
  }
}

export default class EntryAbility extends FlutterAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info(TAG, 'onCreate: setting viewId');
    AppStorage.Set<string>('viewId', this.context.abilityInfo.name);
    super.onCreate(want, launchParam);
    console.info(TAG, 'onCreate: done');
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    console.info(TAG, 'configureFlutterEngine START');
    super.configureFlutterEngine(flutterEngine);
    console.info(TAG, 'super done');
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    console.info(TAG, 'plugins registered');

    const channel = new MethodChannel(
      flutterEngine.getDartExecutor(),
      'com.twt.service/saveImg',
      StandardMethodCodec.INSTANCE
    );
    channel.setMethodCallHandler(new SaveImgHandler(this.context));
  }
}
