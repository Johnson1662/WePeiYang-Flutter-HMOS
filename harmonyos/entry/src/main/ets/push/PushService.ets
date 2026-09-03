import pushService from '@hms.core.push.pushService';
import { BusinessError } from '@ohos.base';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'PushService';

/**
 * 华为推送（Push Kit）桥接。
 *
 * 前置条件（由 AGC / 应用市场侧配置，本文件不涉及）：
 *  1. AGC 控制台开通 Push 服务并配置 client_id（module.json5 metadata）；
 *  2. 工程放入 agconnect-services.json；
 *  3. 真机登录华为账号且系统支持 HMS Push。
 * 在上述配置缺失时，getToken 会失败并返回空串，调用方需自行降级。
 */
export class PushService {
  /** 获取推送 token；失败返回空串，不抛异常。 */
  static async getToken(): Promise<string> {
    try {
      return await pushService.getToken();
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'getToken failed: %{public}s', JSON.stringify(err));
      return '';
    }
  }

  /** 推送初始化占位：token 拉取即初始化，此处仅作通道握手。 */
  static async init(): Promise<boolean> {
    try {
      const token = await PushService.getToken();
      hilog.info(DOMAIN, TAG, 'push init done, token len=%{public}d', token.length);
      return token.length > 0;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'push init failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }
}
