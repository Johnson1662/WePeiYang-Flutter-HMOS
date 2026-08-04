/**
 * WePeiYang Course Schedule Service Widget (FormExtensionAbility).
 *
 * Reads schedule data from a JSON file written by the Flutter app's
 * WidgetDataSync, filters courses for today, and provides them to the
 * widget page via formBindingData.
 */
import { FormExtensionAbility, formBindingData, FormInfo } from '@kit.FormKit';
import { fileIo } from '@kit.CoreFileKit';

const TAG = 'SDCFormAbility';

/// Calculate the current academic week from termStart (unix timestamp).
/// Returns 0 if before term start or calculation fails.
function calcCurrentWeek(termStartSec: number): number {
  const nowMs = Date.now();
  const termStartMs = termStartSec * 1000;
  const diffMs = nowMs - termStartMs;
  if (diffMs <= 0) return 0;
  const weekFloat = diffMs / (7 * 24 * 60 * 60 * 1000);
  return Math.ceil(weekFloat);
}

/// Get today's weekday (1 = Monday, 7 = Sunday).
function getTodayWeekday(): number {
  const day = new Date().getDay();
  return day === 0 ? 7 : day;
}

/// Format time slot from unit numbers (1-based).
/// Returns a string like "08:30-10:05".
function formatTimeSlot(startUnit: number, endUnit: number): string {
  // Standard class time mapping (TJU):
  // Unit 1: 08:30-09:15, Unit 2: 09:20-10:05
  // Unit 3: 10:25-11:10, Unit 4: 11:15-12:00
  // Unit 5: 14:00-14:45, Unit 6: 14:50-15:35
  // Unit 7: 15:50-16:35, Unit 8: 16:40-17:25
  // Unit 9: 19:00-19:45, Unit 10: 19:50-20:35
  const unitTimes: Record<number, string> = {
    1: '08:30', 2: '09:20', 3: '10:25', 4: '11:15',
    5: '14:00', 6: '14:50', 7: '15:50', 8: '16:40',
    9: '19:00', 10: '19:50',
  };
  const start = unitTimes[startUnit] || '';
  // End time is the start of the last unit + 45min (quick estimate)
  // For the last unit, use approximate end
  const endUnitStart = unitTimes[endUnit];
  let endTime = '';
  if (endUnitStart) {
    const [h, m] = endUnitStart.split(':').map(Number);
    const endMin = h * 60 + m + 45;
    const endH = Math.floor(endMin / 60);
    const endM = endMin % 60;
    endTime = `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}`;
  }
  return start && endTime ? `${start}-${endTime}` : '';
}

export default class ScheduleFormAbility extends FormExtensionAbility {
  onAddForm(want: import('@kit.AbilityKit').Want): formBindingData.FormBindingData {
    console.info(TAG, 'onAddForm called');
    return this.loadFormData();
  }

  onUpdateForm(formId: string): void {
    console.info(TAG, 'onUpdateForm called for form: ' + formId);
    const formData = this.loadFormData();
    this.updateForm(formId, formData);
  }

  onCastToForm(formId: string): void {
    console.info(TAG, 'onCastToForm called for form: ' + formId);
    const formData = this.loadFormData();
    this.updateForm(formId, formData);
  }

  onFormEvent(formId: string, message: string): void {
    console.info(TAG, 'onFormEvent form=' + formId + ' message=' + message);
    // Handle FormLink events: "router" or "message"
    if (message === 'openApp') {
      try {
        this.context.startAbility({
          bundleName: 'com.twt.service',
          abilityName: 'EntryAbility',
        });
      } catch (e) {
        console.warn(TAG, 'startAbility failed: ' + JSON.stringify(e));
      }
    }
  }

  /// Read the JSON file written by the Flutter app and build form data.
  private loadFormData(): formBindingData.FormBindingData {
    try {
      const path = this.context.cacheDir + '/schedule_widget_data.json';
      console.info(TAG, 'loadFormData: reading from ' + path);
      const text = fileIo.readTextSync(path);
      const data = JSON.parse(text);
      const courseDataStr: string = data.courseData || '';
      const termStart: number = data.termStart || 0;

      if (!courseDataStr) {
        console.info(TAG, 'loadFormData: no courseData');
        return formBindingData.createFormBindingData({
          courses: [],
          isEmpty: true,
          lastUpdate: Date.now(),
        });
      }

      const parsed = JSON.parse(courseDataStr);
      const schoolCourses: any[] = parsed.schoolCourses || [];
      const customCourses: any[] = parsed.customCourses || [];

      const today = getTodayWeekday();
      const currentWeek = calcCurrentWeek(termStart);
      console.info(TAG, `loadFormData: today=${today} week=${currentWeek}`);

      const todayCourses: Array<{
        name: string;
        location: string;
        time: string;
      }> = [];

      const processCourse = (course: any) => {
        let name = course.name || '未知课程';
        if (name.length > 10) name = name.substring(0, 8) + '...';
        const arrangeList: any[] = course.arrangeList || [];
        for (const arrange of arrangeList) {
          const weekday: number = arrange.weekday || 0;
          if (weekday !== today) continue;

          // Check weekList matches current week
          const weekList: number[] = arrange.weekList || [];
          if (weekList.length > 0 && !weekList.includes(currentWeek)) continue;

          let location: string = (arrange.location || '').replace(/-/g, '楼');
          if (location === '') location = '————';

          const unitList: number[] = arrange.unitList || [];
          const time = unitList.length >= 2
            ? formatTimeSlot(unitList[0], unitList[unitList.length - 1])
            : '';

          todayCourses.push({ name, location, time });
        }
      };

      for (const c of schoolCourses) processCourse(c);
      for (const c of customCourses) processCourse(c);

      // Sort by start time (time string first 5 chars)
      todayCourses.sort((a, b) => a.time.localeCompare(b.time));

      console.info(TAG, `loadFormData: found ${todayCourses.length} courses for today`);
      return formBindingData.createFormBindingData({
        courses: todayCourses,
        isEmpty: todayCourses.length === 0,
        lastUpdate: Date.now(),
      });
    } catch (e) {
      console.warn(TAG, 'loadFormData error: ' + JSON.stringify(e));
      return formBindingData.createFormBindingData({
        courses: [],
        isEmpty: true,
        lastUpdate: Date.now(),
      });
    }
  }
}
