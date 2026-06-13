import router from '@ohos.router';
import { Article } from '../model/Article';
import { ArticleRepository } from '../repository/ArticleRepository';
import { CheckInRecord } from '../model/CheckInRecord';
import { CheckInRepository } from '../repository/CheckInRepository';
import { Config } from '../model/Config';
import { ConfigRepository } from '../repository/ConfigRepository';
import { DailyTaskService } from '../service/DailyTaskService';
import { DailyTaskItem } from '../repository/DailyTaskRepository';

interface TaskItemUI {
  taskId: number;
  articleId: number;
  articleTitle: string;
  wordTarget: number;
  isCheckedIn: boolean;
  isRequired: boolean;
  isLongArticle: boolean;
  displayName: string;
  progressPercent: number;
}

@Entry
@Component
struct HomePage {
  @State tasks: TaskItemUI[] = [];
  @State isLoading: boolean = true;
  @State config: Config = new Config();
  @State totalCheckIns: number = 0;
  @State todayCheckIns: number = 0;
  @State totalWordsToday: number = 0;
  @State targetWordsToday: number = 0;
  @State completedTasksCount: number = 0;
  @State requiredTasksCount: number = 0;
  @State requiredCompleted: number = 0;

  @Watch('onRefreshSignalChanged')
  @StorageProp('dataRefreshSignal') refreshSignal: string = '';

  // 数据预加载就绪标志 - 由 SplashPage 在预加载完成后设置
  @Watch('onDailyTaskPreloadedChanged')
  @StorageProp('dailyTaskPreloaded') dailyTaskPreloaded: boolean = false;

  aboutToAppear(): void {
    this.isLoading = true;
    this.loadData();
  }

  aboutToShow(): void {
    // 每次页面显示时强制刷新数据（特别是从阅读页面返回时）
    // 这里不设置 isLoading=true，让 UI 保持可读性，同时后台刷新
    this.loadDataWithOptionalLoading(true);
  }

  /**
   * 带可选 loading 状态的刷新
   * showLoading=true: 显示 loading，覆盖旧数据
   * showLoading=false: 不显示 loading，直接用新数据覆盖（无闪烁）
   */
  async loadDataWithOptionalLoading(showLoading: boolean): Promise<void> {
    const prevTasks = [...this.tasks];
    if (showLoading) {
      this.isLoading = true;
    }
    try {
      await ArticleRepository.getInstance().resetCheckInDaysIfNeeded();

      this.config = await ConfigRepository.getInstance().getConfig();
      const rateWordsPerMin: number = 250;
      this.targetWordsToday = this.config.dailyMinutes * rateWordsPerMin;

      const allArticles: Article[] = await ArticleRepository.getInstance().getAllArticles();
      console.info('Home.loadData: allArticles.length=' + allArticles.length);

      const dailyTaskService = DailyTaskService.getInstance();
      // 先检查是否有今日任务（依赖 count 字段，避免 items 查询异常误判）
      const hasTodayTasks = await dailyTaskService.hasTodayTasks();
      console.info('Home.loadData: hasTodayTasks=' + hasTodayTasks);

      let taskItems = await dailyTaskService.getOrGenerateTodayTasks(allArticles);
      console.info('Home.loadData: taskItems.length after getOrGenerate=' + taskItems.length);

      // 防御性修复：如果 hasTodayTasks 为 true 但 items 为空，
      // 说明 items 查询可能有异常——再尝试一次 getTodayTasks
      if (hasTodayTasks && taskItems.length === 0) {
        console.warn('Home.loadData: hasTodayTasks=true 但 taskItems 为空，重试 getTodayTasks');
        taskItems = await dailyTaskService.getTodayTasks();
        console.info('Home.loadData: 重试后 taskItems.length=' + taskItems.length);
      }

      this.tasks = [];
      for (let i = 0; i < taskItems.length; i++) {
        const item = taskItems[i];
        const article = allArticles.find(a => a.id === item.articleId);
        const display = item.displayName && item.displayName.length > 0
          ? item.displayName
          : (item.articleTitle || (article ? article.title : '未命名文章'));
        this.tasks.push({
          taskId: item.taskId,
          articleId: item.articleId,
          articleTitle: item.articleTitle || (article ? article.title : ''),
          wordTarget: item.wordTarget > 0 ? item.wordTarget : (article ? article.chineseChars : 0),
          isCheckedIn: item.isCheckedIn,
          isRequired: item.isRequired,
          isLongArticle: item.isLongArticle,
          displayName: display,
          progressPercent: article ? article.completionRate : 0
        });
      }
      console.info('Home.loadData: 最终构建 tasks.length=' + this.tasks.length
        + '，其中已完成=' + this.tasks.filter(t => t.isCheckedIn).length);

      const allCheckIns: CheckInRecord[] = await CheckInRepository.getInstance().getAllCheckInRecords();
      const todayDate: Date = new Date();
      const year: number = todayDate.getFullYear();
      const month: string = (todayDate.getMonth() + 1).toString().padStart(2, '0');
      const day: string = todayDate.getDate().toString().padStart(2, '0');
      const todayStr: string = `${year}-${month}-${day}`;

      let todayCount: number = 0;
      for (let j: number = 0; j < allCheckIns.length; j++) {
        if (allCheckIns[j].checkInDate === todayStr) {
          todayCount = todayCount + 1;
        }
      }
      this.todayCheckIns = todayCount;
      this.totalCheckIns = allCheckIns.length;

      let wordsInToday: number = 0;
      let completedInToday: number = 0;
      let requiredInToday: number = 0;
      let requiredDoneInToday: number = 0;

      for (let i = 0; i < this.tasks.length; i++) {
        const item = this.tasks[i];
        wordsInToday += item.wordTarget;
        if (item.isCheckedIn) {
          completedInToday++;
        }
        if (item.isRequired) {
          requiredInToday++;
          if (item.isCheckedIn) {
            requiredDoneInToday++;
          }
        }
      }

      this.totalWordsToday = wordsInToday;
      this.completedTasksCount = completedInToday;
      this.requiredTasksCount = requiredInToday;
      this.requiredCompleted = requiredDoneInToday;
    } catch (e) {
      console.error('加载首页数据失败: ' + JSON.stringify(e));
      // 恢复之前的数据，避免白屏
      if (prevTasks.length > 0) {
        this.tasks = prevTasks;
      }
    } finally {
      this.isLoading = false;
    }
  }

  // 监听预加载标志位
  onDailyTaskPreloadedChanged(): void {
    console.info('Home: 检测到预加载完成，刷新数据');
    this.loadDataWithOptionalLoading(true);
  }

  onRefreshSignalChanged(): void {
    console.info('Home: 检测到刷新信号，刷新数据');
    this.loadDataWithOptionalLoading(false);
  }

  onRefresh(): void {
    this.loadDataWithOptionalLoading(true);
  }

  // 原有 loadData 保持兼容
  async loadData(): Promise<void> {
    await this.loadDataWithOptionalLoading(true);
  }

  @Builder
  TaskCard(item: TaskItemUI): void {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(item.displayName)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(item.isCheckedIn ? '#999999' : '#333333')
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            if (item.isCheckedIn) {
              Text('已完成')
                .fontSize(10)
                .backgroundColor('#4CAF50')
                .fontColor('#FFFFFF')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
                .margin({ left: 8 });
            }
          }
          .width('100%');
          Row() {
            Text(`${item.wordTarget}字`)
              .fontSize(12)
              .fontColor('#999999');
          }
          .width('100%')
          .margin({ top: 4 });
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1);

        if (item.isCheckedIn) {
          Text('✓')
            .fontSize(24)
            .fontColor('#4CAF50')
            .fontWeight(FontWeight.Bold);
        } else {
          Text('○')
            .fontSize(24)
            .fontColor('#E0E0E0');
        }
      }
      .width('100%');
    }
    .width('100%')
    .padding(16)
    .backgroundColor(item.isCheckedIn ? '#E9DEEE' : '#F5F5F5')
    .borderRadius(8)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/Reader',
        params: { articleId: item.articleId }
      });
    });
  }

  build(): void {
    Column() {
      Row() {
        Text('每日阅读')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })
      .backgroundColor('#FFFFFF');

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40);
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 });
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .padding({ top: 100 })
        .backgroundColor('#F5F5F5');
      } else {
        Scroll() {
          Column({ space: 16 }) {
            Column() {
              Row() {
                Text('今日目标')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold);
                Blank();
                Text(`${this.completedTasksCount}/${this.tasks.length}`)
                  .fontSize(14)
                  .fontColor('#666666');
              }
              .width('100%');
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(`${this.targetWordsToday}`)
                    .fontSize(16)
                    .fontColor('#1976D2')
                    .fontWeight(FontWeight.Bold);
                  Text('目标字数')
                    .fontSize(12)
                    .fontColor('#999999');
                }
                .layoutWeight(1);
                Column({ space: 4 }) {
                  Text(`${this.totalWordsToday}`)
                    .fontSize(16)
                    .fontColor('#333333')
                    .fontWeight(FontWeight.Bold);
                  Text('今日文章字数')
                    .fontSize(12)
                    .fontColor('#999999');
                }
                .layoutWeight(1);
                Column({ space: 4 }) {
                  Text(`${Math.round(this.config.targetCheckRate)}%`)
                    .fontSize(16)
                    .fontColor('#4CAF50')
                    .fontWeight(FontWeight.Bold);
                  Text('目标完成率')
                    .fontSize(12)
                    .fontColor('#999999');
                }
                .layoutWeight(1);
              }
              .width('100%')
              .margin({ top: 8 });

              if (this.requiredTasksCount > 0) {
                Row({ space: 8 }) {
                  Text(`必读:${this.requiredCompleted}/${this.requiredTasksCount}`)
                    .fontSize(12)
                    .fontColor('#D32F2F')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor('#FFEBEE')
                    .borderRadius(4);
                }
                .width('100%')
                .margin({ top: 8 });
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(8);

            Column({ space: 8 }) {
              Row() {
                Text('今日任务')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold);
              }
              .width('100%');

              if (this.tasks.length === 0) {
                Column() {
                  Text('暂无文章，请先在文章管理中添加文章并标记为"阅读中"')
                    .fontSize(14)
                    .fontColor('#999999')
                    .textAlign(TextAlign.Center);
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
                .margin({ top: 16, bottom: 16 });
              } else {
                ForEach(this.tasks, (item: TaskItemUI) => {
                  this.TaskCard(item);
                }, (item: TaskItemUI) => `${item.taskId}-${item.articleId}`);
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(8);
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ bottom: 80 });
        }
        .scrollBar(BarState.On)
        .width('100%')
        .layoutWeight(1)
        .padding({ top: 16 })
        .backgroundColor('#F5F5F5')
        .scrollable(ScrollDirection.Vertical);
      }

      this.BottomTabBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
  }

  @Builder
  BottomTabBar(): void {
    Row() {
      Column({ space: 2 }) {
        Text('●')
          .fontSize(18)
          .fontColor('#999999');
        Text('首页')
          .fontSize(11)
          .fontColor('#1976D2')
          .fontWeight(FontWeight.Bold);
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 });

      Column({ space: 2 }) {
        Text('▣')
          .fontSize(16)
          .fontColor('#999999');
        Text('文章管理')
          .fontSize(11)
          .fontColor('#666666');
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/ArticleManage' });
      });

      Column({ space: 2 }) {
        Text('◈')
          .fontSize(16)
          .fontColor('#999999');
        Text('随心阅读')
          .fontSize(11)
          .fontColor('#666666');
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/RandomRead' });
      });

      Column({ space: 2 }) {
        Text('◆')
          .fontSize(16)
          .fontColor('#999999');
        Text('背穴位')
          .fontSize(11)
          .fontColor('#666666');
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/AcupointStudy' });
      });

      Column({ space: 2 }) {
        Text('◇')
          .fontSize(16)
          .fontColor('#999999');
        Text('背概念')
          .fontSize(11)
          .fontColor('#666666');
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/ConceptStudy' });
      });

      Column({ space: 2 }) {
        Text('⚙')
          .fontSize(16)
          .fontColor('#999999');
        Text('设置')
          .fontSize(11)
          .fontColor('#666666');
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/Settings' });
      });
    }
    .width('100%')
    .backgroundColor('#FFFFFF');
  }
}
