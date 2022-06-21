public without sharing class CallLWCDisasterSupport {
    /**
     * LWCから呼び出されるメソッド。
     * 引数の収受日に対して、収受簿レコードの審査を行い、進捗状況を「審査NG」または、「審査OK」とする。
     *
     * @param 画面入力値：審査対象の収受日
     * @return 審査レコード件数
     */
    @AuraEnabled
    public static Integer requestExamination(Date inputReceiptDate){
        Integer examinationedRecordCount = 0;

        // 1. Databaseクラスを使用してsavepointを作成する。
        Savepoint savePoint = Database.setSavepoint();

        try {
            // 2. 収受簿オブジェクトから、収受日が「inputReceiptDate（引数）」と一致し、進捗状況が「収受」または「審査NG」であるレコードをList型で取得する。
            String targetReceiptDate = DateTime.newInstance(inputReceiptDate.year(), inputReceiptDate.month(), inputReceiptDate.day()).format('yyyy-MM-dd');
            String sql = 'SELECT' + ' '
                            + 'Id' + ',' + ' '
                            + 'OwnerId' + ',' + ' '
                            + 'IsDeleted' + ',' + ' '
                            + 'Name' + ',' + ' '
                            + 'CreatedDate' + ',' + ' '
                            + 'CreatedById' + ',' + ' '
                            + 'LastModifiedDate' + ',' + ' '
                            + 'LastModifiedById' + ',' + ' '
                            + 'SystemModstamp' + ',' + ' '
                            + 'LastViewedDate' + ',' + ' '
                            + 'LastReferencedDate' + ',' + ' '
                            + 'StateProgress__c' + ',' + ' '
                            + 'Disaster__c' + ',' + ' '
                            + 'Disaster__r.Name' + ',' + ' '
                            + 'ReceiptDate__c' + ',' + ' '
                            + 'FullName__c' + ',' + ' '
                            + 'Ruby__c' + ',' + ' '
                            + 'RequestCategory__c' + ' '
                        + 'FROM' + ' '
                            + 'ReceiptJournal__c' + ' '
                        + 'WHERE' + ' '
                            + '(StateProgress__c = \'収受\' OR StateProgress__c = \'審査NG\') AND ReceiptDate__c = ' + targetReceiptDate;
            List<ReceiptJournal__c> examinationTargetReceiptJournalList = Database.query(sql);
            for (ReceiptJournal__c examinationTargetReceiptJournalRecord : examinationTargetReceiptJournalList) {
                examinationTargetReceiptJournalRecord.StateProgress__c = '審査中';
            }

                    // 3. 2で取得した収受簿レコードのリストに対して、繰り返し処理を行う。
            List<String> duplicateValidateSelectIndex = new List<String>();
            for (ReceiptJournal__c examinationTargetReceiptJournalRecord : examinationTargetReceiptJournalList) {
                //     3-1. 氏名、ふりがな、申請区分がそれぞれ「Null」である場合、または、氏名、ふりがながそれぞれ「空文字」である場合に下記の処理を行う。
                if(String.isEmpty(examinationTargetReceiptJournalRecord.FullName__c)
                    || String.isEmpty(examinationTargetReceiptJournalRecord.Ruby__c)
                    || String.isEmpty(examinationTargetReceiptJournalRecord.RequestCategory__c)){

                    // 3-1-1. 進捗状況に「審査NG」を代入する。
                    examinationTargetReceiptJournalRecord.StateProgress__c = '審査NG';
                    // 3-1-2. 審査NGとなった件数を、検査レコード件数として加算する。（初期値は0）
                    examinationedRecordCount += 1;

                }
                // 3-2. 3-1を除く場合に書くの処理を行う。
                else{
                    // 3-2-1. 震災名とふりがなを結合した文字列をList型変数に追加する。
                    duplicateValidateSelectIndex.add(
                        examinationTargetReceiptJournalRecord.Disaster__r.Name + examinationTargetReceiptJournalRecord.Ruby__c
                        );
                }
            }

            // 4. 支給台帳オブジェクトから、レコード重複判定項目が「3-2-1で取得したリスト」と一致するレコードをList型で取得する。（IN句を使用すること）
            List<ProvidedLedger__c> duplicateValidateProvidedLedgerList = (List<ProvidedLedger__c>)[
                SELECT
                    Id,
                    OwnerId,
                    IsDeleted,
                    Name,
                    CreatedDate,
                    CreatedById,
                    LastModifiedDate,
                    LastModifiedById,
                    SystemModstamp,
                    LastViewedDate,
                    LastReferencedDate,
                    ReceiptJournal__c,
                    Disaster__c,
                    FullName__c,
                    Ruby__c,
                    RequestCategory__c,
                    ProvidedDate__c,
                    ReceiptDate__c,
                    RecordDuplicateString__c
                FROM ProvidedLedger__c
                WHERE RecordDuplicateString__c IN :duplicateValidateSelectIndex
            ];

            // 5. 2で取得した収受簿レコードのリストに対して、繰り返し処理を行う。
            for (ReceiptJournal__c examinationTargetReceiptJournalRecord : examinationTargetReceiptJournalList) {
                // 5-1. 進捗状況が「審査中」の場合、下記の処理を行う。
                if(
                    examinationTargetReceiptJournalRecord.StateProgress__c.equals('審査中')
                ){
                    String duplicateStringReceiptJournal = examinationTargetReceiptJournalRecord.Disaster__r.Name + examinationTargetReceiptJournalRecord.Ruby__c;

                    // 5-1-1. 申請区分が「基礎」の場合、下記の処理を行う。
                    if(examinationTargetReceiptJournalRecord.RequestCategory__c.equals('基礎')){
                        // 5-1-1-1. 4で取得した支給台帳オブジェクトのリストが0件の場合、進捗状況に「審査OK」を代入する。
                        // 5-1-1-2. 審査OKとなった件数を、検査レコード件数として加算する。（初期値は0）
                        if(duplicateValidateProvidedLedgerList.size() == 0){
                            examinationTargetReceiptJournalRecord.StateProgress__c = '審査OK';
                            examinationedRecordCount += 1;
                        }
                        // 5-1-1-3. 4で取得した支給台帳オブジェクトのリストと繰り返し比較し、震災名とふりがなを結合した文字列と一致した場合に下記の処理を行う。
                        for (ProvidedLedger__c duplicateValidateProvidedLedgerRecord : duplicateValidateProvidedLedgerList) {
                            if(duplicateStringReceiptJournal == duplicateValidateProvidedLedgerRecord.RecordDuplicateString__c){
                                // 5-1-1-3-1. 進捗状況に「審査NG」を代入する。
                                // 5-1-1-3-2. 審査NGとなった件数を、検査レコード件数として加算する。（初期値は0）
                                examinationTargetReceiptJournalRecord.StateProgress__c = '審査NG';
                                examinationedRecordCount += 1;
                            }else{
                                // 5-1-1-3-3. 進捗状況に「審査OK」を代入する。
                                // 5-1-1-3-4. 審査OKとなった件数を、検査レコード件数として加算する。（初期値は0）
                                examinationTargetReceiptJournalRecord.StateProgress__c = '審査OK';
                                examinationedRecordCount += 1;
                            }
                        }
                    }
                    // 5-1-2. 申請区分が「加算」の場合、下記の処理を行う。
                    if(examinationTargetReceiptJournalRecord.RequestCategory__c.equals('加算')){
                        // 5-1-2-1. 4で取得した支給台帳オブジェクトのリストが0件の場合、進捗状況に「審査NG」を代入する。
                        // 5-1-2-2. 審査NGとなった件数を、検査レコード件数として加算する。（初期値は0）
                        if(duplicateValidateProvidedLedgerList.size() == 0){
                            examinationTargetReceiptJournalRecord.StateProgress__c = '審査NG';
                            examinationedRecordCount += 1;
                        }
                        // 5-1-2-3. 4で取得した支給台帳オブジェクトのリストと繰り返し比較し、震災名とふりがなを結合した文字列と一致した場合に下記の処理を行う。
                        for (ProvidedLedger__c duplicateValidateProvidedLedgerRecord : duplicateValidateProvidedLedgerList) {
                            if(duplicateStringReceiptJournal == duplicateValidateProvidedLedgerRecord.RecordDuplicateString__c){
                                // 5-1-2-3-1. 進捗状況に「審査OK」を代入する。
                                // 5-1-2-3-2. 審査OKとなった件数を、検査レコード件数として加算する。（初期値は0）
                                examinationTargetReceiptJournalRecord.StateProgress__c = '審査OK';
                                examinationedRecordCount += 1;
                            }else{
                                // 5-1-2-3-3. 進捗状況に「審査NG」を代入する。
                                // 5-1-2-3-4. 審査NGとなった件数を、検査レコード件数として加算する。（初期値は0）
                                examinationTargetReceiptJournalRecord.StateProgress__c = '審査NG';
                                examinationedRecordCount += 1;
                            }
                        }
                    }
                }
            }

            // 6. 2で取得した収受簿レコードのリストに対して、UPDATE（DML）を実行する。
            UPDATE examinationTargetReceiptJournalList;

        // 6-1. DML操作で例外が発生した場合はcatchし、下記の処理を行う。
        } catch (DmlException e) {
            // 6-1-1. 1で作成したsavepointまでDBのロールバックを行う。
            Database.rollback(savePoint);
            // 6-1-2. デバッグログを出力する。
            System.debug(System.LoggingLevel.DEBUG, e);
            // 6-1-3. 戻り値として0を返し、メソッドを終了する。
            return 0;

        // なんか補完で出てきたので調査ようにそのままに（↓）
        } catch (Exception e) {
            // AuraEnabled特有の例外クラス？
            throw new AuraHandledException(e.getMessage());
        }

        // 7. 戻り値として、検査レコードの件数を返す。

        return examinationedRecordCount;
    }

    /**
     * LWCから呼び出されるメソッド。
     * 引数の収受日に対して、収受簿レコードの審査を行い、進捗状況を「審査NG」または、「審査OK」とする。
     *
     * @param 画面入力値：審査対象の収受日
     * @return 支給決定レコード件数
     */
    @AuraEnabled
    public static Integer decisionGrant(Date inputReceiptDate, Date inputPayDate){
        Integer decisionedGrantRecordCount = 0;

        // 1. Databaseクラスを使用してsavepointを作成する。
        Savepoint savePoint = Database.setSavepoint();

        try {
            // 2. 収受簿オブジェクトから、収受日が「inputReceiptDate（引数）」と一致し、進捗状況が「審査OK」であるレコードをList型で取得する。
            String targetReceiptDate = DateTime.newInstance(inputReceiptDate.year(), inputReceiptDate.month(), inputReceiptDate.day()).format('yyyy-MM-dd');
            String sql = 'SELECT' + ' '
                            + 'Id' + ',' + ' '
                            + 'OwnerId' + ',' + ' '
                            + 'IsDeleted' + ',' + ' '
                            + 'Name' + ',' + ' '
                            + 'CreatedDate' + ',' + ' '
                            + 'CreatedById' + ',' + ' '
                            + 'LastModifiedDate' + ',' + ' '
                            + 'LastModifiedById' + ',' + ' '
                            + 'SystemModstamp' + ',' + ' '
                            + 'LastViewedDate' + ',' + ' '
                            + 'LastReferencedDate' + ',' + ' '
                            + 'StateProgress__c' + ',' + ' '
                            + 'Disaster__c' + ',' + ' '
                            + 'Disaster__r.Name' + ',' + ' '
                            + 'ReceiptDate__c' + ',' + ' '
                            + 'FullName__c' + ',' + ' '
                            + 'Ruby__c' + ',' + ' '
                            + 'RequestCategory__c' + ' '
                        + 'FROM' + ' '
                            + 'ReceiptJournal__c' + ' '
                        + 'WHERE' + ' '
                            + 'StateProgress__c = \'審査OK\' AND ReceiptDate__c = ' + targetReceiptDate;
            List<ReceiptJournal__c> grantTargetReceiptJournalList = Database.query(sql);

            // 3. 2で取得した収受簿レコードのリストに対して、繰り返し処理を行う。
            for (ReceiptJournal__c grantTargetReceiptJournalRecord : grantTargetReceiptJournalList) {
                // 	3-1. 進捗状況を「審査OK」から「支給済」に変更する。
                grantTargetReceiptJournalRecord.StateProgress__c = '支給済';
            }

            // 4. 2で取得した収受簿レコードのリストに対して、UPDATE（DML）を実行する。
            UPDATE grantTargetReceiptJournalList;

            // 5. List型で支給台帳オブジェクトのレコードリストを宣言する。
            List<ProvidedLedger__c> grantTargetProvidedLedgerList = new List<ProvidedLedger__c>();

            // 6. 2で取得した収受簿レコードのリストに対して繰り返し処理を行い、下記の条件で5で宣言した支給台帳レコードリストの初期化（レコード情報の追加）を行う。
            for (ReceiptJournal__c grantTargetReceiptJournalRecord : grantTargetReceiptJournalList) {
                grantTargetProvidedLedgerList.add(
                // 6-1. 進捗状況が「支給済」である場合、下記の処理を行う。
                // 6-1-1. 支給台帳型のオブジェクトを作成し、リストに追加する。
                    new ProvidedLedger__c(
                        // 収受番号 ： 収受簿レコードの値
                        ReceiptJournal__c = grantTargetReceiptJournalRecord.Id,
                        // 災害名   ： 収受簿レコードの値
                        Disaster__c = grantTargetReceiptJournalRecord.Disaster__c,
                        // 氏名     ： 収受簿レコードの値
                        FullName__c = grantTargetReceiptJournalRecord.FullName__c,
                        // ふりがな ： 収受簿レコードの値
                        Ruby__c = grantTargetReceiptJournalRecord.Ruby__c,
                        // 申請区分 ： 収受簿レコードの値
                        RequestCategory__c = grantTargetReceiptJournalRecord.RequestCategory__c,
                        // 支給日   ： 引数のinputPayDateの値
                        ProvidedDate__c = inputPayDate,
                        // 収受日   ： 収受簿レコードの値
                        ReceiptDate__c = grantTargetReceiptJournalRecord.ReceiptDate__c
                    )
                );
                // 6-1-2. 6-1-1を行うごとに支給決定レコード件数として加算する。（初期値は0）
                decisionedGrantRecordCount += 1;
            }

            // 7. 5で宣言した支給台帳レコードのリストに対して、INSERT（DML）を実行する。
            INSERT grantTargetProvidedLedgerList;

        // 4-1 & 7-1. DML操作で例外が発生した場合はcatchし、下記の処理を行う。
        } catch (DmlException e) {
            // 4-1-1 & 7-1-1. 1で作成したsavepointまでDBのロールバックを行う。
            Database.rollback(savePoint);
            // 4-1-2 & 7-1-2. デバッグログを出力する。
            System.debug(System.LoggingLevel.DEBUG, e);
            // 4-1-3 & 7-1-3. 戻り値として0を返し、メソッドを終了する。
            return 0;

        // なんか補完で出てきたので調査ようにそのままに（↓）
        } catch (Exception e) {
            // AuraEnabled特有の例外クラス？
            throw new AuraHandledException(e.getMessage());
        }

        // 8. 戻り値として、支給決定レコード件数を返す。
        return decisionedGrantRecordCount;
    }
}
