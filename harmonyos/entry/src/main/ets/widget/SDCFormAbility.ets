/**
 * WePeiYang Course Schedule Service Widget (FormExtensionAbility).
 *
 * Reads schedule data from a JSON file written by the Flutter app's
 * WidgetDataSync, filters courses for today, and provides them to the
 * widget page via formBindingData.
 */
import fs from '@ohos.file.fs';
import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Context } from '@kit.AbilityKit';

const TAG = 'SDCFormAbility';

interface CourseItem {
  name: string;
  location: string;
  time: string;
  timeStart: string;
  timeEnd: string;
}

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
    // Save the form ID so EntryAbility can trigger immediate updates
    try {
      const path: string = this.context.cacheDir + '/schedule_form_id.txt';
      const params: Record<string, Object> = want.parameters as Record<string, Object>;
      const extraForm: Record<string, Object> = (params ? params['ohos.extra.form'] : null) as Record<string, Object>;
      const formId: string = extraForm ? (extraForm['formId'] as string) : '';
      if (formId) {
        const wf = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
        fs.writeSync(wf.fd, formId);
        fs.closeSync(wf);
        console.log(TAG, 'onAddForm: saved formId ' + formId);
      }
    } catch (e) {
      console.error(TAG, 'onAddForm: save formId failed: ' + JSON.stringify(e));
    }
    return this.loadFormData();
  }

  onUpdateForm(formId: string): void {
    console.info(TAG, 'onUpdateForm called');
    const formData: formBindingData.FormBindingData = this.loadFormData();
    try {
      formProvider.updateForm(formId, formData);
    } catch (e) {
      console.warn(TAG, 'updateForm failed: ' + JSON.stringify(e));
    }
  }

  onCastToForm(formId: string): void {
    console.info(TAG, 'onCastToForm called');
    this.onUpdateForm(formId);
  }

  /// Read the JSON file written by the Flutter app and build form data.
  private loadFormData(): formBindingData.FormBindingData {
    // Try to read from application-level cache
    let courseDataStr: string = '';
    let currentWeek: number = 1;
    // Try to read from cache dir (same as Flutter's Directory.systemTemp)
    try {
      const path: string = this.context.cacheDir + '/schedule_widget_data.json';
      console.log(TAG, 'loadFormData: trying ' + path);
      const text: string = fs.readTextSync(path);
      const data: Record<string, Object> = JSON.parse(text);
      courseDataStr = (data['courseData'] as string) || '';
      currentWeek = (data['currentWeek'] as number) || 1;
      console.log(TAG, 'loadFormData: read ok, week=' + currentWeek + ' dataLen=' + courseDataStr.length);
    } catch (e) {
      console.error(TAG, 'loadFormData: tempDir failed: ' + JSON.stringify(e));
      // Fallback: try application cache dir
      try {
        const appCtx: Context = this.context.getApplicationContext();
        const path2: string = appCtx.cacheDir + '/schedule_widget_data.json';
        console.log(TAG, 'loadFormData: fallback ' + path2);
        const text2: string = fs.readTextSync(path2);
        const data2: Record<string, Object> = JSON.parse(text2);
        courseDataStr = (data2['courseData'] as string) || '';
        currentWeek = (data2['currentWeek'] as number) || 1;
        console.log(TAG, 'loadFormData: fallback ok, week=' + currentWeek);
      } catch (e2) {
        console.error(TAG, 'loadFormData: all paths failed');
      }
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
    return formBindingData.createFormBindingData({
      courses: todayCourses,
      isEmpty: todayCourses.length === 0,
      lastUpdate: Date.now(),
    });
  }
}
