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
import { camera, cameraPicker } from '@kit.CameraKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { common, Want, AbilityConstant, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import pasteboard from '@ohos.pasteboard';
import { BusinessError } from '@ohos.base';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { formBindingData, formProvider } from '@kit.FormKit';
// 入校码卡片已下线（校方授权落地前不冒充学校教务接口）；
// EntryQrService / EntryQrFormAbility / EntryQrFormCard 已删除。
import deviceInfo from '@ohos.deviceInfo';
import { PushService } from '../push/PushService';
import { SpeechRecognizerHandler } from '../speech/SpeechRecognizerHandler';
import { UserAuthHandler } from '../userauth/UserAuthHandler';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { updateManager } from '@kit.AppGalleryKit';

// Legacy — kept for Index.ets PickerDialog (currently unused)
export function resolvePickerResult(paths: string[]): void {
  console.info(TAG, 'resolvePickerResult (legacy stub): ' + JSON.stringify(paths));
}

const TAG = 'EntryAbility';

interface FormCourseItem {
  name: string;
  location: string;
  timeStart: string;
  timeEnd: string;
  time: string;
}

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
      case 'shareImage': {
        const path = call.argument('path') as string;
        this.shareImage(path, result);
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
      case 'checkAppUpdate':
        this.checkAppUpdate(result);
        break;
      case 'showAppUpdateDialog':
        this.showAppUpdateDialog(result);
        break;
      case 'triggerFormUpdate': {
        const formId: string = (call.argument as Object) as string;
        if (formId) {
          this.triggerFormUpdate(formId, result);
        } else {
          result.success(false);
        }
        break;
      }
      case 'getDeviceInfo':
        this.getDeviceInfo(result);
        break;
      case 'syncWidgetCourseData': {
        // Argument is a JSON string from Flutter (see WidgetDataSync)
        const jsonStr: string = (call.argument as Object) as string;
        try {
          const parsed: Record<string, Object> = JSON.parse(jsonStr);
          const courseData: string = (parsed['courseData'] as string) || '';
          const currentWeek: number = (parsed['currentWeek'] as number) || 1;
          const termStart: number = (parsed['termStart'] as number) || 0;
          const userNumber: string = (parsed['userNumber'] as string) || '';
          this.syncWidgetCourseData(courseData, currentWeek, termStart, userNumber, result);
        } catch (e) {
          console.warn(TAG, 'syncWidgetCourseData parse error: ' + JSON.stringify(e));
          result.success(false);
        }
        break;
      }
      case 'flutterFirstFrame':
        AppStorage.Set<boolean>('flutterFirstFrame', true);
        result.success(true);
        break;
      case 'consumePendingRoute': {
        // 服务卡片点击直达：返回并清空待跳转路由（冷启动场景）
        const pendingRoute: string = AppStorage.Get<string>('pendingRoute') ?? '';
        AppStorage.Set<string>('pendingRoute', '');
        result.success(pendingRoute);
        break;
      }
      case 'getFilesDir': {
        // 应用持久化文件目录（非 cache，清后台/清理缓存不丢失）
        result.success(this.context.filesDir);
        break;
      }
      default:
        result.notImplemented();
    }
  }

  private async checkAppUpdate(result: MethodResult): Promise<void> {
    console.info(TAG, 'checkAppUpdate: start');
    let replied: boolean = false;
    // 未上架等异常情况下 SDK 可能长时间不返回，必须给出确定的答复。
    const timeoutId: number = setTimeout(() => {
      if (replied) return;
      replied = true;
      console.warn(TAG, 'checkAppUpdate: timed out');
      result.error('APP_UPDATE_TIMEOUT', '检查更新超时', 'timeout');
    }, 8000);
    try {
      const checked = await updateManager.checkAppUpdate(this.context);
      if (replied) return;
      replied = true;
      clearTimeout(timeoutId);
      console.info(TAG, 'checkAppUpdate: available=' + checked.updateAvailable);
      switch (checked.updateAvailable) {
        case updateManager.UpdateAvailableCode.LATER_VERSION_NOT_EXIST:
          result.success(false);
          return;
        case updateManager.UpdateAvailableCode.LATER_VERSION_EXIST:
          result.success(true);
          return;
        default:
          // 未上架时可能返回 -1；不能把未知状态当成“没有新版本”。
          result.error('APP_UPDATE_UNAVAILABLE', '暂无法获取应用市场版本',
            String(checked.updateAvailable));
      }
    } catch (e) {
      if (replied) return;
      replied = true;
      clearTimeout(timeoutId);
      const error = e as BusinessError;
      console.warn(TAG, 'checkAppUpdate failed: ' + JSON.stringify(error));
      result.error('APP_UPDATE_CHECK_FAILED', '检查更新失败',
        error.code + ': ' + error.message);
    }
  }

  private async showAppUpdateDialog(result: MethodResult): Promise<void> {
    try {
      const status = await updateManager.showUpdateDialog(this.context);
      if (status === updateManager.ShowUpdateResultCode.SHOW_DIALOG_SUCCESS) {
        result.success(null);
      } else {
        result.error('APP_UPDATE_DIALOG_FAILED', '无法显示更新提示', status.toString());
      }
    } catch (e) {
      const error = e as BusinessError;
      console.warn(TAG, 'showAppUpdateDialog failed: ' + JSON.stringify(error));
      result.error('APP_UPDATE_DIALOG_FAILED', '无法显示更新提示',
        error.code + ': ' + error.message);
    }
  }

  private async takePhoto(result: MethodResult) {
    console.info(TAG, 'takePhoto entered');
    try {
      if (!canIUse('SystemCapability.Multimedia.Camera.Core')) {
        console.warn(TAG, 'takePhoto: camera capability is unavailable');
        result.success(null);
        return;
      }

      const cacheDir = this.context.cacheDir + '/picker_temp';
      try {
        await fileIo.mkdir(cacheDir, true);
      } catch (e) {
        // The cache directory may already exist after the first capture.
      }
      const capturePath = cacheDir + '/camera_' + Date.now() + '.jpg';
      fileIo.createRandomAccessFileSync(capturePath, fileIo.OpenMode.CREATE);
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
        saveUri: fileUri.getUriFromPath(capturePath),
      };
      const resultData = await cameraPicker.pick(
        this.context,
        [cameraPicker.PickerMediaType.PHOTO],
        profile
      );
      console.info(TAG, 'takePhoto: resultUri=' + resultData.resultUri + ' resultCode=' + resultData.resultCode);

      if (resultData.resultCode === 0 && resultData.resultUri) {
        console.info(TAG, 'takePhoto: saved to ' + capturePath);
        result.success(capturePath);
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

  private triggerFormUpdate(formId: string, result: MethodResult): void {
    try {
      // Read the latest data file and re-send the form binding data
      const path: string = this.context.cacheDir + '/schedule_widget_data.json';
      const text: string = fs.readTextSync(path);
      const data: Record<string, Object> = JSON.parse(text);
      const courseDataStr: string = (data['courseData'] as string) || '';
      const currentWeek: number = (data['currentWeek'] as number) || 1;
      
      // Parse courses the same way SDCFormAbility does
      const todayCourses: FormCourseItem[] = [];
      const today: number = new Date().getDay() === 0 ? 7 : new Date().getDay();
      
      if (courseDataStr) {
        const parsed: Record<string, Object> = JSON.parse(courseDataStr);
        const allCourses: Array<Record<string, Object>> = [...((parsed['schoolCourses'] || []) as Array<Record<string, Object>>), ...((parsed['customCourses'] || []) as Array<Record<string, Object>>)];
        for (const course of allCourses) {
          const name: string = (course['name'] as string) || '未知课程';
          const arranges: Array<Record<string, Object>> = (course['arrangeList'] as Array<Record<string, Object>>) || [];
          for (const arrange of arranges) {
            if ((arrange['weekday'] as number) !== today) continue;
            const weekList: Array<number> = (arrange['weekList'] as Array<number>) || [];
            if (weekList.length > 0 && !weekList.includes(currentWeek)) continue;
            const location: string = ((arrange['location'] as string) || '————').replace(/-/g, '楼');
            const units: Array<number> = (arrange['unitList'] as Array<number>) || [];
            const timeStart: string = ['08:30','09:20','10:25','11:15','14:00','14:50','15:50','16:40','19:00','19:50'][(units[0] || 1) - 1] || '';
            let timeEnd: string = '';
            if (timeStart) {
              const parts: string[] = timeStart.split(':');
              const h: number = Number(parts[0]);
              const m: number = Number(parts[1]);
              const totalMin: number = h * 60 + m + 45;
              const endH: number = Math.floor(totalMin / 60);
              const endM: number = totalMin % 60;
              timeEnd = `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}`;
            }
            const item: FormCourseItem = { name: name, location: location, timeStart: timeStart, timeEnd: timeEnd, time: timeStart ? timeStart + '-' + timeEnd : '' };
            todayCourses.push(item);
          }
        }
        todayCourses.sort((a, b) => a.timeStart.localeCompare(b.timeStart));
      }
      
      const formData: formBindingData.FormBindingData = formBindingData.createFormBindingData({
        courses: todayCourses,
        isEmpty: todayCourses.length === 0,
        lastUpdate: Date.now(),
      });
      formProvider.updateForm(formId, formData);
      console.info(TAG, 'triggerFormUpdate: updated form ' + formId);
      result.success(true);
    } catch (e) {
      console.warn(TAG, 'triggerFormUpdate failed: ' + JSON.stringify(e));
      result.success(false);
    }
  }

  private getDeviceInfo(result: MethodResult): void {
    result.success({
      deviceType: deviceInfo.deviceType,
      manufacturer: deviceInfo.manufacture,
      brand: deviceInfo.brand,
      model: deviceInfo.productModel,
      series: deviceInfo.productSeries,
      osVersion: deviceInfo.osFullName,
      sdkVersion: deviceInfo.sdkApiVersion,
      buildType: deviceInfo.buildType,
      incrementalVersion: deviceInfo.incrementalVersion,
      versionId: deviceInfo.versionId
    });
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

  private syncWidgetCourseData(courseData: string, currentWeek: number, termStart: number, userNumber: string, result: MethodResult): void {
    try {
      const jsonStr = JSON.stringify({
        courseData: courseData,
        currentWeek: currentWeek,
        termStart: termStart,
        userNumber: userNumber,
        lastUpdate: Date.now()
      });

      // filesDir 是持久目录：cache 目录会被系统清理，清掉后卡片会一直停在旧数据，
      // 所以持久副本放第一位，cache 副本只作兼容回退。
      const paths: string[] = [
        this.context.filesDir + '/schedule_widget_data.json',
        this.context.cacheDir + '/schedule_widget_data.json',
        this.context.getApplicationContext().cacheDir + '/schedule_widget_data.json',
      ];
      for (const p of paths) {
        // TRUNC 必带：新内容比旧内容短时不截断会留下尾部残留，JSON.parse 会直接失败
        const f = fs.openSync(p, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        fs.writeSync(f.fd, jsonStr);
        fs.closeSync(f);
      }

      hilog.info(0x0001, TAG, 'syncWidgetCourseData: written %{public}d bytes to %{public}d paths',
        jsonStr.length, paths.length);
      result.success(true);
    } catch (e) {
      hilog.warn(0x0001, TAG, 'syncWidgetCourseData failed: %{public}s', JSON.stringify(e));
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

  private async shareImage(path: string, result: MethodResult): Promise<void> {
    try {
      console.info(TAG, 'shareImage called with path: ' + path);
      if (!path) {
        result.success(false);
        return;
      }

      // 1. 获取文件扩展名与精准 UTD 类型（微信/QQ 等严格依赖精确 UTD 匹配发送界面）
      let ext = '.jpg';
      const lastDot = path.lastIndexOf('.');
      if (lastDot >= 0) {
        ext = path.substring(lastDot).toLowerCase();
      }
      let utdTypeId: string = utd.UniformDataType.IMAGE;
      try {
        const detected = utd.getUniformDataTypeByFilenameExtension(ext, utd.UniformDataType.IMAGE);
        if (detected) {
          utdTypeId = detected;
        }
      } catch (_) {}

      // 2. 将待分享文件复制到标准的跨应用授权共享沙箱目录 context.filesDir/share/
      // 避免源文件位于 temp/cache 目录时导致目标应用（如微信）读取权限受限从而无法展示选人界面
      const shareDir = this.context.filesDir + '/share';
      try {
        await fileIo.mkdir(shareDir, true);
      } catch (_) {}

      const rawFileName = path.split('/').pop() || `share_${Date.now()}${ext}`;
      const fileName = rawFileName.endsWith(ext) ? rawFileName : `${rawFileName}${ext}`;
      const destPath = `${shareDir}/${fileName}`;

      const srcFile = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
      const dstFile = await fileIo.open(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      await fileIo.copyFile(srcFile.fd, dstFile.fd);
      await fileIo.close(srcFile);
      await fileIo.close(dstFile);

      // 3. 生成符合跨应用分享安全规范的沙箱应用文件 URI
      const uri = fileUri.getUriFromPath(destPath);
      console.info(TAG, `shareImage: uri=${uri}, utd=${utdTypeId}`);

      const shareData = new systemShare.SharedData({
        utd: utdTypeId,
        uri: uri,
        title: fileName,
      });
      const controller = new systemShare.ShareController(shareData);
      await controller.show(this.context, {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE,
      });
      console.info(TAG, 'systemShare.show success');
      result.success(true);
    } catch (e) {
      console.error(TAG, 'shareImage failed: ' + JSON.stringify(e));
      result.success(false);
    }
  }
}

export default class EntryAbility extends FlutterAbility {
  private engine: FlutterEngine | null = null;
  private speechHandler: SpeechRecognizerHandler | null = null;

  private extractCardRoute(want: Want): string {
    const directRoute = want.parameters?.['route'];
    if (typeof directRoute === 'string' && directRoute !== '') {
      return directRoute;
    }
    const params = want.parameters?.['params'];
    if (typeof params === 'string' && params !== '') {
      try {
        const parsed = JSON.parse(params) as Record<string, Object>;
        if (typeof parsed?.['route'] === 'string') {
          return parsed['route'] as string;
        }
      } catch (_) {}
    } else if (typeof params === 'object' && params !== null) {
      const record = params as Record<string, Object>;
      if (typeof record['route'] === 'string') {
        return record['route'] as string;
      }
    }
    return '';
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info(TAG, 'onCreate: setting viewId');
    AppStorage.Set<string>('viewId', this.context.abilityInfo.name);
    // 服务卡片点击直达：冷启动时路由参数从 want 带入
    const coldRoute: string = this.extractCardRoute(want);
    if (coldRoute !== '') {
      AppStorage.Set<string>('pendingRoute', coldRoute);
    }
    super.onCreate(want, launchParam);
    console.info(TAG, 'onCreate: done');
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    // 热启动（应用已在运行）时卡片点击直达
    super.onNewWant(want, launchParams);
    const route: string = this.extractCardRoute(want);
    if (route === '') return;
    const firstFrame: boolean = AppStorage.Get<boolean>('flutterFirstFrame') ?? false;
    if (firstFrame) {
      // Flutter 已就绪，直接推送路由
      const flutterEngine = this.engine;
      if (flutterEngine != null) {
        const pushChannel = new MethodChannel(
          flutterEngine.getDartExecutor(),
          'com.twt.service/push',
          StandardMethodCodec.INSTANCE
        );
        pushChannel.invokeMethod('openRoute', { 'route': route });
      }
      return;
    }
    // Flutter 尚未就绪，缓存给冷启动后的 flutterFirstFrame consume
    AppStorage.Set<string>('pendingRoute', route);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    console.info(TAG, 'configureFlutterEngine START');
    this.engine = flutterEngine;
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

    const pushChannel = new MethodChannel(
      flutterEngine.getDartExecutor(),
      'com.twt.service/push',
      StandardMethodCodec.INSTANCE
    );
    pushChannel.setMethodCallHandler(new PushHandler());

    const speechChannel = new MethodChannel(
      flutterEngine.getDartExecutor(),
      'com.twt.service/speech_recognizer',
      StandardMethodCodec.INSTANCE
    );
    this.speechHandler = new SpeechRecognizerHandler(this.context, speechChannel);
    speechChannel.setMethodCallHandler(this.speechHandler);

    const authChannel = new MethodChannel(
      flutterEngine.getDartExecutor(),
      'com.twt.service/user_auth',
      StandardMethodCodec.INSTANCE
    );
    authChannel.setMethodCallHandler(new UserAuthHandler(authChannel));
  }

  onDestroy(): void {
    if (this.speechHandler !== null) {
      this.speechHandler.destroy();
      this.speechHandler = null;
    }
    super.onDestroy();
  }
}

/** 华为推送（Push Kit）通道：Dart 侧 PushManager 通过 com.twt.service/push 调用。 */
class PushHandler implements MethodCallHandler {
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'initPush':
        result.success(await PushService.init());
        break;
      case 'getToken':
        result.success(await PushService.getToken());
        break;
      case 'turnOnPushService':
        // Push Kit 的开关由系统通知权限控制，这里保持兼容返回成功
        result.success('open push service success');
        break;
      case 'turnOffPushService':
        result.success(true);
        break;
      default:
        result.notImplemented();
    }
  }
}
