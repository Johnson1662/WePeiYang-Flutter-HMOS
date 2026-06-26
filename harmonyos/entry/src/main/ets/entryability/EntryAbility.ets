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
import { fileIo } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { common, Want } from '@kit.AbilityKit';
import pasteboard from '@ohos.pasteboard';

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
      default:
        result.notImplemented();
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
      console.error(TAG, 'PhotoViewPicker error code: ' + (e as ESObject).code);
      console.error(TAG, 'PhotoViewPicker error message: ' + (e as ESObject).message);
      result.success([]);
    }
  }

  private getClipboardText(result: MethodResult): void {
    console.info(TAG, 'getClipboardText called');
    try {
      const pb = pasteboard.getSystemPasteboard();
      console.info(TAG, 'got system pasteboard');
      pb.getData((err, data) => {
        if (err) {
          console.warn(TAG, 'getClipboardText callback error: ' + JSON.stringify(err));
          result.success(null);
          return;
        }
        const text = data.getPrimaryText();
        if (text) {
          result.success(text);
        } else {
          result.success(null);
        }
      });
    } catch (e) {
      console.warn(TAG, 'getClipboardText failed: ' + JSON.stringify(e));
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

  private openWebView(url: string, result: MethodResult): void {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        // Open in system browser
        const want: Want = {
          uri: url,
          action: 'ohos.want.action.viewData',
          parameters: {},
        };
        this.context.startAbility(want);
        result.success(true);
      } else {
        console.warn(TAG, 'invalid webview url: ' + url);
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
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    const channel = new MethodChannel(
      flutterEngine.getDartExecutor(),
      'com.twt.service/saveImg',
      StandardMethodCodec.INSTANCE
    );
    channel.setMethodCallHandler(new SaveImgHandler(this.context));
  }
}
