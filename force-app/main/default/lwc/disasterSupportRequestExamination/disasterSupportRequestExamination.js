import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import requestExamination from '@salesforce/apex/CallLWCDisasterSupport.requestExamination';


export default class DisasterSupportRequestExamination extends LightningElement {

    // 収受日の入力値を保持する。
    inputReceiptDate

    // プロパティの初期化を行う。
    constructor(){
        super()
        // getToday関数を呼び出し、戻り値でinputReceiptDateプロパティを初期化する。
        this.inputReceiptDate = this.getToday()
    }

    // 今日の日付を取得して返す。
    getToday(){
        // Dateオブジェクトのインスタンスを作成する。
        // JSTに変換する。（toLocaleStringでタイムゾーンにAsia/Tokyoを使用すること）
        // yyyy-MM-dd形式にフォーマットする。（DateTimeFormatでlocaleにfr-CAを使用すること）
        // 取得値を戻り値として返す。
        return new Intl.DateTimeFormat("fr-CA", {year: "numeric", month: "2-digit", day: "2-digit"}).format(new Date(new Date().toLocaleString({ timeZone: 'Asia/Tokyo' })))
    }

    // 入力値をinputReceiptDateプロパティにバインドする。
    inputReceiptDateChange(event) {
        // inputReceiptDateプロパティに引数のeventのvalueプロパティを代入する。
        this.inputReceiptDate = event.target.value
    }

    // Apexメソッド（CallLWCDisasterSupport.requestExamination()）を呼び出し、収受簿の申請に対して審査を行う。
    // Apexメソッドの処理完了後、トーストメッセージを出力する。
    doRequestExamination(){
        requestExamination({ inputReceiptDate: this.inputReceiptDate })
            .then(result => {
                if (result != '0') {
                    const event = new ShowToastEvent({
                        "message": "正常終了。審査対象：" + result + "件",
                        "variant": "success"
                    });
                    this.dispatchEvent(event);
                } else {
                    const event = new ShowToastEvent({
                        "message": "データが存在しませんでした。",
                        "variant": "error"
                    })
                    console.log("result")
                    console.log(result)
                    this.dispatchEvent(event);
                }
        }).catch(error => {
            const event = new ShowToastEvent({
                "message": "データが存在しませんでした。",
                "variant": "error"
            })
            console.log("error")
            console.log(error)
            this.dispatchEvent(event)
        })
    }
}
