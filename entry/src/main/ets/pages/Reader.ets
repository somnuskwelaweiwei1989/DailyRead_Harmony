import router from '@ohos.router';
import { Article } from '../model/Article';
import { ArticleRepository } from '../repository/ArticleRepository';
import { CheckInRecord } from '../model/CheckInRecord';
import { CheckInRepository } from '../repository/CheckInRepository';
import { DailyTaskService } from '../service/DailyTaskService';
import { DailyTaskRepository } from '../repository/DailyTaskRepository';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct ReaderPage {
  @State article: Article | null = null;
  @State isLoading: boolean = true;
  @State isCheckedIn: boolean = false;
  @State showBars: boolean = false;
  @State fontSize: number = 26;
  @State timerText: string = '00:00';
  private articleId: number = 0;
  private startTimestamp: number = 0;
  private timerHandle: number = -1;

  aboutToAppear(): void {
    const params: Record<string, Object> = router.getParams() as Record<string, Object>;
    if (params && params['articleId'] !== undefined && params['articleId'] !== null) {
      const idNum: number = Number(params['articleId']);
      if (!Number.isNaN(idNum)) {
        this.articleId = idNum;
      }
    }
    this.loadData();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const allArticles: Article[] = await ArticleRepository.getInstance().getAllArticles();
      for (let i: number = 0; i < allArticles.length; i++) {
        if (allArticles[i].id === this.articleId) {
          this.article = allArticles[i];
          break;
        }
      }

      const todayDate: Date = new Date();
      const year: number = todayDate.getFullYear();
      const month: string = (todayDate.getMonth() + 1).toString().padStart(2, '0');
      const day: string = todayDate.getDate().toString().padStart(2, '0');
      const today: string = `${year}-${month}-${day}`;

      const allCheckIns: CheckInRecord[] = await CheckInRepository.getInstance().getAllCheckInRecords();
      for (let j: number = 0; j < allCheckIns.length; j++) {
        if (allCheckIns[j].articleId === this.articleId && allCheckIns[j].checkInDate === today) {
          this.isCheckedIn = true;
          break;
        }
      }

      this.startTimer();
    } catch (e) {
      console.error('加载文章失败: ' + JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  startTimer(): void {
    this.startTimestamp = Date.now();
    this.updateTimerText();
    this.timerHandle = setInterval(() => {
      this.updateTimerText();
    }, 1000);
  }

  stopTimer(): void {
    if (this.timerHandle !== -1) {
      clearInterval(this.timerHandle);
      this.timerHandle = -1;
    }
  }

  updateTimerText(): void {
    const diffMs: number = Date.now() - this.startTimestamp;
    const totalSeconds: number = Math.floor(diffMs / 1000);
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const seconds: number = totalSeconds % 60;
    if (hours > 0) {
      this.timerText = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    } else {
      this.timerText = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
  }

  toggleBars(): void {
    this.showBars = !this.showBars;
  }

  hideBarsOnScroll(): void {
    if (this.showBars) {
      this.showBars = false;
    }
  }

  decreaseFontSize(): void {
    if (this.fontSize > 12) {
      this.fontSize = this.fontSize - 1;
    }
  }

  increaseFontSize(): void {
    if (this.fontSize < 60) {
      this.fontSize = this.fontSize + 1;
    }
  }

  /**
   * 打卡成功后直接调用：文章表的打卡天数 +1 并重新计算完成率
   */
  async handleCheckIn(): Promise<void> {
    if (this.isCheckedIn || this.article === null) {
      return;
    }

    try {
      // 1. 先写入打卡记录表（保留打卡明细）
      const record: CheckInRecord = new CheckInRecord();
      record.articleId = this.article.id;
      const todayDate: Date = new Date();
      const year: number = todayDate.getFullYear();
      const month: string = (todayDate.getMonth() + 1).toString().padStart(2, '0');
      const day: string = todayDate.getDate().toString().padStart(2, '0');
      const dateStr: string = `${year}-${month}-${day}`;
      record.checkInDate = dateStr;
      record.checkInTime = dateStr;
      record.lastModified = new Date().toISOString();
      await CheckInRepository.getInstance().insertCheckInRecord(record);
      this.isCheckedIn = true;

      // 2. 更新文章表的打卡天数和完成率（核心逻辑在这里，不依赖日期解析）
      const rate: number = await ArticleRepository.getInstance().incrementCheckInDays(this.article.id);

      // 3. 标记今日任务中的文章已完成
      // 先刷新一遍，确保获取到最新的 taskId
      const todayTaskRefreshed = await DailyTaskRepository.getInstance().getTodayTask();
      console.info('Reader.handleCheckIn: todayTask.id=' + (todayTaskRefreshed ? todayTaskRefreshed.id : 'null')
        + '，count=' + (todayTaskRefreshed ? todayTaskRefreshed.count : 'N/A')
        + '，items.length=' + (todayTaskRefreshed ? todayTaskRefreshed.items.length : 'N/A'));
      if (todayTaskRefreshed && todayTaskRefreshed.id && todayTaskRefreshed.id > 0) {
        await DailyTaskRepository.getInstance().markArticleChecked(todayTaskRefreshed.id, this.article.id);
        console.info('Reader.handleCheckIn: markArticleChecked 已执行');
      } else {
        console.warn('Reader.handleCheckIn: todayTask.id 无效，跳过 markArticleChecked');
      }

      // 4. 触发全局刷新信号，并强制重新导航到首页
      // 使用 setTimeout 延迟执行，确保所有数据库写操作已完全提交后再导航
      setTimeout(() => {
        console.info('Reader.handleCheckIn: 准备强制刷新首页');
        // 先设置刷新信号（触发 @Watch 响应）
        AppStorage.set('dataRefreshSignal', Date.now().toString());
        // 然后强制 replace 到首页，确保首页完全重新加载
        router.replaceUrl({ url: 'pages/Home' });
        console.info('Reader.handleCheckIn: 已导航到首页');
      }, 100);

      promptAction.showToast({ message: `打卡成功，完成率 ${rate}%`, duration: 2000 });
    } catch (e) {
      console.error('打卡失败: ' + JSON.stringify(e));
    }
  }

  build(): void {
    Stack() {
      Column() {
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
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#FFFFFF');
        } else {
          if (this.article !== null) {
            Scroll() {
              Column() {
                Text(this.article.title)
                  .fontSize(this.fontSize + 6)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333333')
                  .margin({ bottom: 8 })
                  .width('100%')
                  .textAlign(TextAlign.Start);

                Text(`${this.article.chineseChars} 字`)
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ bottom: 16 })
                  .width('100%');

                Text(this.article.content)
                  .fontSize(this.fontSize)
                  .fontColor('#333333')
                  .lineHeight(this.fontSize * 1.8)
                  .width('100%')
                  .textAlign(TextAlign.Start);

                Column() {
                  if (this.isCheckedIn) {
                    Text('✓ 今日已打卡')
                      .fontSize(16)
                      .fontColor('#4CAF50')
                      .fontWeight(FontWeight.Bold)
                      .padding({ left: 24, right: 24, top: 12, bottom: 12 })
                      .backgroundColor('#E8F5E9')
                      .borderRadius(8);
                  } else {
                    Text('打卡此文章')
                      .fontSize(16)
                      .fontColor('#FFFFFF')
                      .fontWeight(FontWeight.Bold)
                      .padding({ left: 24, right: 24, top: 12, bottom: 12 })
                      .backgroundColor('#4CAF50')
                      .borderRadius(8)
                      .onClick(() => {
                        this.handleCheckIn();
                      });
                  }
                }
                .width('100%')
                .margin({ top: 32, bottom: 32 })
                .alignItems(HorizontalAlign.Center);
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16);
            }
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
            .width('100%')
            .align(Alignment.Top)
            .backgroundColor('#FFFFFF')
            .onScroll(() => {
              this.hideBarsOnScroll();
            })
            .onClick(() => {
              this.toggleBars();
            });
          } else {
            Column() {
              Text('文章未找到')
                .fontSize(16)
                .fontColor('#999999');
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#FFFFFF');
          }
        }
      }
      .width('100%')
      .height('100%');

      if (this.showBars) {
        Column() {
          Row() {
            Row() {
              Text('←')
                .fontSize(22)
                .fontColor('#333333')
                .margin({ right: 8 });
              Text(this.article !== null ? this.article.title : '')
                .fontSize(16)
                .fontColor('#333333')
                .fontWeight(FontWeight.Medium)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1);
            }
            .layoutWeight(1)
            .onClick(() => {
              router.back();
            });

            Text(this.timerText)
              .fontSize(16)
              .fontColor('#1976D2')
              .fontWeight(FontWeight.Bold)
              .margin({ left: 12 });
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor('#FFFFFF');
        }
        .width('100%')
        .position({ x: 0, y: 0 });
      }

      if (this.showBars) {
        Column() {
          Row() {
            Text('A-')
              .fontSize(20)
              .fontColor('#333333')
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .onClick(() => {
                this.decreaseFontSize();
              });

            Text(this.fontSize.toString())
              .fontSize(18)
              .fontColor('#1976D2')
              .fontWeight(FontWeight.Bold)
              .layoutWeight(1)
              .textAlign(TextAlign.Center);

            Text('A+')
              .fontSize(20)
              .fontColor('#333333')
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .onClick(() => {
                this.increaseFontSize();
              });
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor('#FFFFFF');
        }
        .width('100%')
        .position({ x: 0, y: '100%' })
        .translate({ y: '-100%' });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
