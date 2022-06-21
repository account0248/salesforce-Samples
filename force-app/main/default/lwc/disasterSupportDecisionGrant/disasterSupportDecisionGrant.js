import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import decisionGrant from '@salesforce/apex/CallLWCDisasterSupport.decisionGrant';

export default class DisasterSupportDecisionGrant extends LightningElement {

    // 収受日の入力値を保持する。
    inputReceiptDate
    // 支給日の入力値を保持する。
    inputPayDate

    // 入力値をinputReceiptDateプロパティにバインドする。
    inputReceiptDateChange(event){
        // inputReceiptDateプロパティに引数のeventのvalueプロパティを代入する。
        this.inputReceiptDate = event.target.value
    }

    // 入力値をinputReceiptDateプロパティにバインドする。
    inputPayDateChange(event){
        // inputReceiptDateプロパティに引数のeventのvalueプロパティを代入する。
        this.inputPayDate = event.target.value
    }

    // Apexメソッド（CallLWCDisasterSupport.decisionGrant()）を呼び出し、支給日を決定する。
    // Apexメソッドの処理完了後、トーストメッセージを出力する。
    doDecisionGrant(){
        decisionGrant({
                inputReceiptDate: this.inputReceiptDate,
                inputPayDate: this.inputPayDate
            })
            .then(result => {
                if (result != '0') {
                    const event = new ShowToastEvent({
                        "message": "正常終了。支給対象：" + result + "件",
                        "variant": "success"
                    });
                    this.dispatchEvent(event)
                } else {
                    const event = new ShowToastEvent({
                        "message": "データが存在しませんでした。",
                        "variant": "error"
                    });
                    console.log("result")
                    console.log(result)
                    this.dispatchEvent(event)
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
