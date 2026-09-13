import { userAuth } from '@kit.UserAuthenticationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'UserAuthHandler';
const DOMAIN = 0x0000;

export class UserAuthHandler implements MethodCallHandler {
  private channel: MethodChannel;

  constructor(channel: MethodChannel) {
    this.channel = channel;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'authenticate':
        await this.handleAuthenticate(call, result);
        break;
      case 'isBiometricAvailable':
        this.checkBiometricAvailable(result);
        break;
      default:
        result.notImplemented();
    }
  }

  private checkBiometricAvailable(result: MethodResult): void {
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL1);
      result.success(true);
    } catch (_) {
      result.success(false);
    }
  }

  private async handleAuthenticate(call: MethodCall, result: MethodResult): Promise<void> {
    const title: string = (call.argument('title') as string) || '验证以查看个人成绩';
    hilog.info(DOMAIN, TAG, `handleAuthenticate called with title: ${title}`);

    try {
      // 挑战值：6 字节随机/固定数组
      const challenge = new Uint8Array([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc]);

      const authParam: userAuth.AuthParam = {
        challenge: challenge,
        authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL1,
      };

      const widgetParam: userAuth.WidgetParam = {
        title: title,
      };

      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);

      userAuthInstance.on('result', {
        onResult: (authResult: userAuth.UserAuthResult) => {
          hilog.info(DOMAIN, TAG, `userAuth onResult: code=${authResult.result}`);
          try {
            userAuthInstance.off('result');
          } catch (_) {}

          if (authResult.result === userAuth.UserAuthResultCode.SUCCESS) {
            result.success(true);
          } else {
            result.success(false);
          }
        }
      });

      userAuthInstance.start();
      hilog.info(DOMAIN, TAG, 'userAuthInstance.start invoked');
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, `UserAuth failed to start: ${JSON.stringify(err)}`);
      result.success(false);
    }
  }
}
