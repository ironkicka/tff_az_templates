import { AzureFunction, Context } from "@azure/functions"
import {createConnection} from 'mysql2/promise'

const IoTHubTrigger: AzureFunction = async function (context: Context, IoTHubMessage: any): Promise<void> {
// ①接続情報オブジェクトを作成し、コネクションを確立する
    const config =
        {
            host: process.env['DB_HOST'],
            user: process.env['DB_USER_NAME'],
            password: process.env['DB_PASSWORD'],
            database: process.env['DB_DATABASE_NAME'],
            port: 3306,
            ssl : {
                rejectUnauthorized: false
             }
        };

    const conn = await createConnection(config);

//②DBへinsert
    try {
        const [rows,fields] =
          await conn.query(`insert into test_table (message) values ('${IoTHubMessage.value}')`)
            .catch(e=>{throw Error(e)});
        context.log(fields)
      } catch(e) {
        context.log(e)
      } finally {
        conn.end();//接続を切る
      }
};

export default IoTHubTrigger;
