/**
 * WePeiYang Course Schedule Service Widget (FormExtensionAbility).
 *
 * Reads schedule data from a JSON file written by the Flutter app's
 * WidgetDataSync, filters courses for today, and provides them to the
 * widget page via formBindingData.
 */
import fs from '@ohos.file.fs';
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Context } from '@kit.AbilityKit';

const TAG = 'SDCFormAbility';

interface CourseItem {
  name: string;
  location: string;
  time: string;
  timeStart: string;
  timeEnd: string;
}

interface ScheduleFormBinding {
  courses: CourseItem[];
  isEmpty: boolean;
  lastUpdate: number;
  formDimension?: string;
  weekday?: number;
  hasData?: boolean;
}

/// 卡片数据文件：filesDir 优先（cache 会被系统清理），cache 目录仅作兼容回退
const DATA_FILE = 'schedule_widget_data.json';
const FORM_ID_FILE = 'schedule_form_id.txt';
const FORM_DIM_FILE = 'schedule_form_dims.json';

interface CourseArrange {
  weekday: number;
  weekList: number[];
  unitList: number[];
  location: string;
}

interface CourseData {
  name: string;
  arrangeList: CourseArrange[];
}

/// Get today's weekday (1 = Monday, 7 = Sunday).
function getTodayWeekday(): number {
  const day = new Date().getDay();
  return day === 0 ? 7 : day;
}

/// Format time slot from unit numbers (1-based).
/// Returns a string like "08:30-10:05".
function formatTimeSlot(startUnit: number, endUnit: number): string {
  const unitTimes: Record<number, string> = {
    1: '08:30', 2: '09:20', 3: '10:25', 4: '11:15',
    5: '14:00', 6: '14:50', 7: '15:50', 8: '16:40',
    9: '19:00', 10: '19:50',
  };
  const start = unitTimes[startUnit] || '';
  const endUnitStart = unitTimes[endUnit];
  let endTime = '';
  if (endUnitStart) {
    const parts: string[] = endUnitStart.split(':');
    const h: number = Number(parts[0]);
    const m: number = Number(parts[1]);
    const endMin: number = h * 60 + m + 45;
    const endH: number = Math.floor(endMin / 60);
    const endM: number = endMin % 60;
    endTime = `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}`;
  }
  return start && endTime ? `${start}-${endTime}` : '';
}

/// Format time slot returning [start, end] pair.
function formatTimePair(startUnit: number, endUnit: number): [string, string] {
  const unitTimes: Record<number, string> = {
    1: '08:30', 2: '09:20', 3: '10:25', 4: '11:15',
    5: '14:00', 6: '14:50', 7: '15:50', 8: '16:40',
    9: '19:00', 10: '19:50',
  };
  const start = unitTimes[startUnit] || '';
  const endUnitStart = unitTimes[endUnit];
  let endTime = '';
  if (endUnitStart) {
    const parts: string[] = endUnitStart.split(':');
    const h: number = Number(parts[0]);
    const m: number = Number(parts[1]);
    const endMin: number = h * 60 + m + 45;
    endTime = `${String(Math.floor(endMin / 60)).padStart(2, '0')}:${String(endMin % 60).padStart(2, '0')}`;
  }
  return [start, endTime];
}

export default class ScheduleFormAbility extends FormExtensionAbility {
  onAddForm(want: import('@kit.AbilityKit').Want): formBindingData.FormBindingData {
    console.log(TAG, 'onAddForm called');
    let dimension = '2*4';
    try {
      const dimKey = formInfo.FormParam.DIMENSION_KEY || 'ohos.extra.param.key.form_dimension';
      const dim = (want.parameters ? want.parameters[dimKey] : null) as number;
      if (dim === 2) dimension = '2*2';
      else if (dim === 4) dimension = '4*4';
    } catch (_) {}
    // Save the form ID so EntryAbility can trigger immediate updates
    try {
      const path: string = this.context.filesDir + '/' + FORM_ID_FILE;
      const params: Record<string, Object> = want.parameters as Record<string, Object>;
      const extraForm: Record<string, Object> = (params ? params['ohos.extra.form'] : null) as Record<string, Object>;
      const formId: string = extraForm ? (extraForm['formId'] as string) : '';
      if (formId) {
        const wf = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        fs.writeSync(wf.fd, formId);
        fs.closeSync(wf);
        this.saveFormDim(formId, dimension);
        console.log(TAG, 'onAddForm: saved formId ' + formId + ' dimension ' + dimension);
      }
    } catch (e) {
      console.error(TAG, 'onAddForm: save formId failed: ' + JSON.stringify(e));
    }
    return this.loadFormData(dimension);
  }

  onUpdateForm(formId: string): void {
    // onUpdateForm 只带 formId，尺寸要用添加时记下来的；否则会用默认值覆盖真实尺寸
    const dimension: string = this.readFormDims()[formId] ?? '2*4';
    console.info(TAG, 'onUpdateForm called, dimension=' + dimension);
    const formData: formBindingData.FormBindingData = this.loadFormData(dimension);
    try {
      formProvider.updateForm(formId, formData);
    } catch (e) {
      console.warn(TAG, 'updateForm failed: ' + JSON.stringify(e));
    }
  }

  onRemoveForm(formId: string): void {
    console.info(TAG, 'onRemoveForm called');
    this.removeFormDim(formId);
  }

  onCastToForm(formId: string): void {
    console.info(TAG, 'onCastToForm called');
    this.onUpdateForm(formId);
  }

  /// 每个 formId 的卡片尺寸，存在 filesDir（cache 被清理也不会丢）
  private formDimPath(): string {
    return this.context.filesDir + '/' + FORM_DIM_FILE;
  }

  private readFormDims(): Record<string, string> {
    try {
      const text: string = fs.readTextSync(this.formDimPath());
      return JSON.parse(text) as Record<string, string>;
    } catch (e) {
      return {};
    }
  }

  private writeFormDims(dims: Record<string, string>): void {
    try {
      const wf = fs.openSync(this.formDimPath(), fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(wf.fd, JSON.stringify(dims));
      fs.closeSync(wf);
    } catch (e) {
      console.warn(TAG, 'writeFormDims failed: ' + JSON.stringify(e));
    }
  }

  private saveFormDim(formId: string, dimension: string): void {
    const dims: Record<string, string> = this.readFormDims();
    dims[formId] = dimension;
    this.writeFormDims(dims);
  }

  private removeFormDim(formId: string): void {
    const dims: Record<string, string> = this.readFormDims();
    const next: Record<string, string> = {};
    for (const key of Object.keys(dims)) {
      if (key !== formId) {
        next[key] = dims[key];
      }
    }
    this.writeFormDims(next);
  }

  /// Read the JSON file written by the Flutter app and build form data.
  private loadFormData(dimension?: string): formBindingData.FormBindingData {
    let courseDataStr: string = '';
    let currentWeek: number = 1;
    let termStart: number = 0;
    // filesDir 优先，cache 目录只作兼容回退（系统清理缓存后仍能读到持久副本）
    const appCtx: Context = this.context.getApplicationContext();
    const candidates: string[] = [
      this.context.filesDir + '/' + DATA_FILE,
      this.context.cacheDir + '/' + DATA_FILE,
      appCtx.cacheDir + '/' + DATA_FILE,
    ];
    for (const path of candidates) {
      try {
        const text: string = fs.readTextSync(path);
        const data: Record<string, Object> = JSON.parse(text);
        courseDataStr = (data['courseData'] as string) || '';
        currentWeek = (data['currentWeek'] as number) || 1;
        termStart = (data['termStart'] as number) || 0;
        console.info(TAG, 'loadFormData: read ok from ' + path + ' dataLen=' + courseDataStr.length);
        break;
      } catch (e) {
        console.warn(TAG, 'loadFormData: miss ' + path);
      }
    }

    // 学期开始时间可用时自己推算周次：不依赖 App 上次写入，跨周/跨天卡片能自己滚动
    if (termStart > 0) {
      const nowSec: number = Math.floor(Date.now() / 1000);
      const diff: number = nowSec - termStart;
      currentWeek = diff <= 0 ? 1 : Math.min(24, Math.ceil(diff / 604800));
    }

    if (!courseDataStr) {
      console.error(TAG, 'loadFormData: no course data found');
    }

    // Parse courses
    const todayCourses: CourseItem[] = [];
    const today: number = getTodayWeekday();

    if (courseDataStr) {
      try {
        const parsed: Record<string, Object> = JSON.parse(courseDataStr);
        const schoolCourses: CourseData[] = (parsed['schoolCourses'] as CourseData[]) || [];
        const customCourses: CourseData[] = (parsed['customCourses'] as CourseData[]) || [];
        console.info(TAG, 'loadFormData: total course entries=' + (schoolCourses.length + customCourses.length));

        const processCourse = (course: CourseData): void => {
          let name: string = course.name || '未知课程';
          if (name.length > 10) name = name.substring(0, 8) + '...';
          for (const arrange of (course.arrangeList || [])) {
            if (arrange.weekday !== today) continue;
            const weekList: number[] = arrange.weekList || [];
            if (weekList.length > 0 && !weekList.includes(currentWeek)) continue;
            let location: string = (arrange.location || '').replace(/-/g, '楼');
            if (location === '') location = '————';
            const unitList: number[] = arrange.unitList || [];
            const time: string = unitList.length >= 2
              ? formatTimeSlot(unitList[0], unitList[unitList.length - 1])
              : '';
            const timePair: [string, string] = unitList.length >= 2
              ? formatTimePair(unitList[0], unitList[unitList.length - 1])
              : ['', ''];
            todayCourses.push({ name: name, location: location, time: time, timeStart: timePair[0], timeEnd: timePair[1] });
          }
        };
        for (const c of schoolCourses) processCourse(c);
        for (const c of customCourses) processCourse(c);
      } catch (parseErr) {
        console.warn(TAG, 'loadFormData: parse error: ' + JSON.stringify(parseErr));
      }
    }

    todayCourses.sort((a: CourseItem, b: CourseItem) => a.time.localeCompare(b.time));
    console.info(TAG, 'loadFormData: found ' + todayCourses.length + ' courses today');
    const bindingObj: ScheduleFormBinding = {
      courses: todayCourses,
      isEmpty: todayCourses.length === 0,
      lastUpdate: Date.now(),
      formDimension: dimension || '2*4',
      weekday: getTodayWeekday(),
      hasData: courseDataStr.length > 0,
    };
    return formBindingData.createFormBindingData(bindingObj);
  }
}
