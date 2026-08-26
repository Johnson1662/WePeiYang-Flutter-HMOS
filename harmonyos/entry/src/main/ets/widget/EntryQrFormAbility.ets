import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Configuration, Want } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';

import { EntryQrData, loadEntryQrData } from './EntryQrService';

const TAG: string = 'EntryQrFormAbility';
const FORM_ID_FILE: string = 'entry_qr_form_id.txt';

function bindingData(data: EntryQrData): formBindingData.FormBindingData {
  return formBindingData.createFormBindingData({
    qrContent: data.qrContent,
    status: data.status,
    lastUpdate: data.lastUpdate
  });
}

export default class EntryQrFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = this.readFormId(want);
    if (formId.length > 0) {
      this.saveFormId(formId);
      setTimeout(() => this.updateForm(formId), 0);
    }
    return bindingData({
      qrContent: '',
      status: '正在获取入校码',
      lastUpdate: ''
    });
  }

  onUpdateForm(formId: string): void {
    this.updateForm(formId);
  }

  onFormEvent(formId: string, message: string): void {
    console.info(TAG, 'refresh event: ' + message);
    this.updateForm(formId);
  }

  onCastToForm(formId: string): void {
    this.updateForm(formId);
  }

  onRemoveForm(formId: string): void {
    try {
      const path: string = this.context.cacheDir + '/' + FORM_ID_FILE;
      fs.unlinkSync(path);
    } catch (e) {
      console.warn(TAG, 'remove form id failed: ' + JSON.stringify(e));
    }
  }

  onConfigurationUpdate(config: Configuration): void {
    console.info(TAG, 'configuration updated: ' + JSON.stringify(config));
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private readFormId(want: Want): string {
    try {
      const params: Record<string, Object> = want.parameters as Record<string, Object>;
      const extraForm: Record<string, Object> =
        (params ? params['ohos.extra.form'] : null) as Record<string, Object>;
      return extraForm ? (extraForm['formId'] as string) || '' : '';
    } catch (e) {
      console.warn(TAG, 'read form id failed: ' + JSON.stringify(e));
      return '';
    }
  }

  private saveFormId(formId: string): void {
    try {
      const path: string = this.context.cacheDir + '/' + FORM_ID_FILE;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, formId);
      fs.closeSync(file);
    } catch (e) {
      console.warn(TAG, 'save form id failed: ' + JSON.stringify(e));
    }
  }

  private updateForm(formId: string): void {
    loadEntryQrData([
      this.context.cacheDir,
      this.context.getApplicationContext().cacheDir
    ]).then((data: EntryQrData) => {
      formProvider.updateForm(formId, bindingData(data)).catch((error: Error) => {
        console.warn(TAG, 'update form failed: ' + JSON.stringify(error));
      });
    }).catch((error: Error) => {
      console.warn(TAG, 'load QR data failed: ' + JSON.stringify(error));
    });
  }
}
