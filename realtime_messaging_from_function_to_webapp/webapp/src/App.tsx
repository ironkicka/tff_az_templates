import React, {useEffect, useState} from 'react';
import './App.css';
import * as signalR from '@microsoft/signalr'
const connection = new signalR.HubConnectionBuilder()
  .withUrl(`https://${process.env.REACT_APP_NEGOTIATOR_NAME}.azurewebsites.net/api`)
  .configureLogging(signalR.LogLevel.Trace)
  .withAutomaticReconnect()
  .build()

function App() {
  const [data,setData] = useState({message:'',timestamp:''})

  useEffect(()=>{
    connection.on('test', data => {
      console.log("Received data from signalR")
      console.log(data)
      setData(data)
    })

    connection.onclose(function() {
      console.log('signalr disconnected')
    })
    connection.onreconnecting(err =>
      console.log('err reconnecting  ', err)
    )
    connection
      .start()
      .then((res:any) => {})
      .catch(console.error)
  },[])

  return (
    <>
      <div>Message from SignalR</div>
      <div>{data.message}</div>
      <div>arrived at {data.timestamp}</div>
    </>
  );
}

export default App;
