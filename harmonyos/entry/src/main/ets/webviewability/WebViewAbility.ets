import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { AbilityStageConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import router from '@ohos.router';

export default class WebViewAbility extends UIAbility {
  private url: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('WebViewAbility', 'onCreate');
    if (want && want.parameters) {
      const urlParam = want.parameters['url'] as string;
      if (urlParam && urlParam.length > 0) {
        this.url = urlParam;
      }
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('WebViewAbility', 'onWindowStageCreate url=' + this.url);
    windowStage.loadContent('pages/WebViewPage', (err, data) => {
      if (err.code) {
        console.error('WebViewAbility', 'loadContent failed: ' + JSON.stringify(err));
        return;
      }
      console.info('WebViewAbility', 'loadContent succeeded');
    });
  }
}
