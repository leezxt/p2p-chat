# P2P Modular Messenger UML

本文件將開發總規格 v1.2 的核心架構整理為可由 Mermaid 渲染的 UML 視圖。

## 系統部署圖

```mermaid
flowchart LR
    userA["使用者 A"] --> phoneA["手機 App A<br/>主身份裝置"]
    userB["使用者 B"] --> phoneB["手機 App B<br/>主身份裝置"]
    desktop["Flutter Desktop<br/>授權副裝置"]

    subgraph phoneAData["A 裝置本機邊界"]
        phoneA --> sqliteA[("SQLite<br/>聊天、聯絡人、佇列")]
        phoneA --> keyA["Keystore / Keychain<br/>私鑰與裝置金鑰"]
    end

    subgraph phoneBData["B 裝置本機邊界"]
        phoneB --> sqliteB[("SQLite<br/>聊天、聯絡人、佇列")]
        phoneB --> keyB["Keystore / Keychain<br/>私鑰與裝置金鑰"]
    end

    phoneA <-->|"WebRTC DataChannel<br/>端對端加密訊息"| phoneB
    phoneA <-->|"QR 授權、必要資料與新訊息同步"| desktop

    subgraph relay["免費 / 低成本中轉服務"]
        signaling["Signaling<br/>Offer / Answer / ICE"]
        presence["Presence<br/>低頻 Last Seen"]
        mailbox[("Offline Mailbox<br/>只暫存密文")]
        push["FCM / APNs<br/>喚醒通知"]
    end

    phoneA <-->|"建立 P2P 所需資訊"| signaling
    phoneB <-->|"建立 P2P 所需資訊"| signaling
    phoneA -->|"前景低頻更新"| presence
    phoneB -->|"前景低頻更新"| presence
    phoneA <-->|"P2P 失敗時上傳 / 拉取密文"| mailbox
    phoneB <-->|"P2P 失敗時上傳 / 拉取密文"| mailbox
    mailbox -->|"MAILBOX_AVAILABLE"| push
    push --> phoneA
    push --> phoneB
```

## Core 與 Modules 元件圖

```mermaid
flowchart TB
    app["Flutter Application"] --> registry["Module Registry"]

    subgraph core["Core System"]
        registry
        lifecycle["Module Lifecycle"]
        eventBus["Event Bus"]
        routing["Route Registry"]
        di["Dependency Injection"]
        database["Local Database"]
        cryptoService["Crypto Service"]
        networkService["Network Service"]
        storageService["Storage Service"]
        permissionService["Permission Service"]
        loggingService["Logging Service"]
        resourcePolicy["Resource Policy Service"]
    end

    registry --> lifecycle
    registry --> foundation
    registry --> experience
    registry --> security
    registry --> advanced

    subgraph foundation["Foundation Modules"]
        identity["Identity"]
        contacts["Contacts"]
        chat["Chat"]
        p2p["P2P"]
        crypto["Crypto"]
        mailboxModule["Mailbox"]
        notification["Notification"]
        presenceModule["Presence"]
        settings["Settings"]
    end

    subgraph experience["Experience Modules"]
        reaction["Reaction"]
        sticker["Sticker / Creator"]
        voiceMessage["Voice Message"]
        imageMessage["Image Message"]
        translation["Translation"]
        smartNotification["Smart Notification"]
    end

    subgraph security["Device / Security Modules"]
        appLock["App Lock"]
        safetyNumber["Safety Number"]
        lowPower["Low Power Mode"]
        storageManager["Storage Manager"]
        desktopLink["Desktop Link"]
        deviceSync["Device Sync"]
        deviceRevoke["Device Revoke"]
    end

    subgraph advanced["Advanced Modules"]
        fileTransfer["File Transfer"]
        calls["Voice / Video Call"]
        group["Small Group / Broadcast"]
        collaboration["Shared Notes / Todo"]
        ai["Live Caption / Writing Assist / Summary"]
    end

    foundation -. "發布 / 訂閱事件" .-> eventBus
    experience -. "發布 / 訂閱事件" .-> eventBus
    security -. "發布 / 訂閱事件" .-> eventBus
    advanced -. "發布 / 訂閱事件" .-> eventBus

    chat --> database
    p2p --> networkService
    crypto --> cryptoService
    mailboxModule --> networkService
    sticker --> storageService
    calls --> permissionService
    lowPower --> resourcePolicy
    lifecycle --> resourcePolicy
    foundation --> routing
    foundation --> di
    foundation --> loggingService
```

跨模組只透過 Event Bus 與 Core service 契約溝通；Chat Module 不直接依賴 P2P、Sticker 或其他功能模組的內部實作。

## 訊息傳送循序圖

```mermaid
sequenceDiagram
    autonumber
    actor Sender as 傳送者
    participant ChatA as A: Chat Module
    participant CryptoA as A: Crypto Module
    participant P2P as P2P Module
    participant Signal as Signaling
    participant ChatB as B: Chat Module
    participant Mailbox as Offline Mailbox
    participant Push as Push Service

    Sender->>ChatA: 傳送訊息
    ChatA->>ChatA: 寫入 SQLite，狀態 PENDING
    ChatA->>CryptoA: 產生 EncryptedEnvelope
    CryptoA-->>ChatA: 回傳密文 envelope
    ChatA->>P2P: MessageSendRequested(envelope)
    P2P->>Signal: Offer / Answer / ICE
    Signal-->>P2P: Signaling 完成

    alt DataChannel 建立成功
        P2P->>ChatB: 傳送密文 envelope
        ChatB->>ChatB: 驗證、解密並寫入 SQLite
        ChatB-->>P2P: DELIVERED ACK
        P2P-->>ChatA: MessageDelivered
        ChatA->>ChatA: 更新為 DELIVERED
    else P2P 重連後仍失敗
        P2P-->>ChatA: MessageFailed
        ChatA->>Mailbox: 冪等上傳同一密文 envelope
        Mailbox-->>ChatA: STORED
        ChatA->>ChatA: 更新為 STORED
        Mailbox->>Push: 建立 MAILBOX_AVAILABLE 通知
        Push-->>ChatB: 喚醒或提示同步
        ChatB->>Mailbox: 認證後拉取密文
        Mailbox-->>ChatB: 密文 envelope
        ChatB->>ChatB: Replay 檢查、解密、寫入 SQLite
        ChatB->>Mailbox: DELIVERED ACK
        Mailbox->>Mailbox: 清除 ciphertext
        Mailbox-->>ChatA: Sender status = DELIVERED
        ChatA->>ChatA: 更新為 DELIVERED
    end

    opt 接收者開啟聊天室
        ChatB->>Mailbox: READ ACK
        Mailbox-->>ChatA: Sender status = READ
        ChatA->>ChatA: 更新為 READ
    end
```

## 模組生命週期狀態圖

```mermaid
stateDiagram-v2
    [*] --> installed: 安裝模組
    installed --> enabled: 使用者或設定啟用
    enabled --> active: activate()
    active --> sleeping: sleep() / 閒置 / App 背景
    sleeping --> active: 事件喚醒 / 使用者操作
    enabled --> disabled: 停用
    active --> disabled: dispose() 並停用
    sleeping --> disabled: 停用
    disabled --> enabled: 重新啟用並 init()
    disabled --> [*]: 解除安裝
```

高耗能的語音、視訊、檔案與 AI 模組預設為 `disabled` 或 `sleeping`；只有實際使用時才進入 `active`，結束後立即釋放資源。

## 訊息狀態圖

```mermaid
stateDiagram-v2
    [*] --> PENDING: 本機建立訊息
    PENDING --> SENT: P2P 已送出
    PENDING --> STORED: Mailbox 接受密文
    PENDING --> FAILED: 重試耗盡或不可恢復錯誤
    SENT --> DELIVERED: 對方保存並回 ACK
    STORED --> DELIVERED: 對方拉取、保存並回 ACK
    STORED --> EXPIRED: 超過 TTL
    DELIVERED --> READ: 對方開啟聊天室
    FAILED --> PENDING: 使用者或排程重試
    READ --> [*]
    EXPIRED --> [*]
```

Mailbox 未收到 `DELIVERED` ACK 前不得刪除訊息；收到 ACK 後先清除伺服器端 ciphertext，再保留必要的傳遞狀態供傳送端同步。
