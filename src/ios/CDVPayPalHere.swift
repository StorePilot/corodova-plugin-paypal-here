import PayPalRetailSDK

@objc(CDVPayPalHere) class CDVPayPalHere : CDVPlugin {
	func log(_ msg: String) {
		print("[CDVPayPalHere] " + msg)
	}

	func getJSON (_ d: Dictionary<String, String>) -> String {
		var str = "{"
		for (k, v) in d {
            if (v.hasPrefix("{") || v.hasPrefix("[")) {
                str += "\"\(k)\":\(v),"
            } else {
                str += "\"\(k)\":\"\(v)\","
            }
		}
		str = str.substring(to: str.index(before: str.endIndex))
		str += "}"
		return str
	}
    
    func getJSONForError (_ error: PPRetailError?) -> String {
        if (error != nil) {
            return self.getJSON([
                "debugId": error!.debugId != nil ? error!.debugId! : "",
                "code": error!.code != nil ? error!.code! : "",
                "message": error!.message != nil ? error!.message! : "",
                "developerMessage": error!.developerMessage != nil ? error!.developerMessage! : ""
            ])
        } else {
            return self.getJSON([:])
        }
    }
    
    func logError(error: PPRetailError, context: String) {
        self.log(context)
        self.log(self.getJSONForError(error))
    }

	func getCordovaSuccessCallback(_ command: CDVInvokedUrlCommand) -> (String) -> Void {
		return { (msg: String) in
			self.commandDelegate!.send(
				CDVPluginResult(status: CDVCommandStatus_OK, messageAs: msg),
				callbackId: command.callbackId
			)
		}
	}

	func getCordovaErrorCallback(_ command: CDVInvokedUrlCommand) -> (String) -> Void {
		return { (msg: String) in
			self.commandDelegate!.send(
				CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: msg),
				callbackId: command.callbackId
			)
		}
	}

	// ----------------------------------------------------------------------------------------------

	var merchantInitialized : Bool = false
	var readerConnected: Bool = false

	func initializeMerchant(
		accessToken: String,
		refreshUrl: String,
		environment: String,
		referrerCode: String,
		onSuccess: @escaping (String) -> Void,
		onError: @escaping (String) -> Void
	)  {
		var hasEmptyValues : Bool = false
		if accessToken.isEmpty { hasEmptyValues = true }
		if refreshUrl.isEmpty { hasEmptyValues = true }
		if environment.isEmpty { hasEmptyValues = true }

		if hasEmptyValues {
			// this is needed because PayPalRetailSDK.initializeMerchant just doesn't ever call the callback
			// if any of the values are empty
			onError("accessToken, refreshUrl, & environment arguments must not be empty")
		} else {
			self.log("INITIALIZE SDK START")
			PayPalRetailSDK.initializeSDK()
			self.log("INITIALIZE SDK SUCCESS")

			self.log("INITIALIZE MERCHANT START")
			let sdkCreds = SdkCredential.init(
				accessToken: accessToken,
				refreshUrl: refreshUrl,
				environment: environment
			)
			PayPalRetailSDK.initializeMerchant(withCredentials: sdkCreds) { (error, merchant) in
				if let err = error {
					self.logError(error: err, context: "INITIALIZE MERCHANT FAILED")
					onError(err.message!)
				} else {
                    if (merchant != nil) {
                        merchant!.referrerCode = referrerCode
                        self.log("INITIALIZE MERCHANT SUCCESS")
                        self.merchantInitialized = true
                        onSuccess("Initialized")
                    } else {
                        onError("No merchant returned from initialization")
                    }
				}
			}
		}
	}

	func checkForReaderUpdate(reader: PPRetailPaymentDevice?) {
		if (reader != nil && reader?.pendingUpdate != nil && (reader?.pendingUpdate?.isRequired)!) {
			reader?.pendingUpdate?.offer({ (error, updateComplete) in
				if (updateComplete) {
					self.log("Reader update complete.")
				} else {
						self.logError(error: error!, context: "READER UPDATE")
				}
			})
		} else {
			self.log("Reader update not required at this time.")
		}
	}

	func getConnectToReaderHandler(
		onSuccess: @escaping (String) -> Void,
		onError: @escaping (String) -> Void
	) -> Optional<(Optional<PPRetailError>, Optional<PPRetailPaymentDevice>) -> ()> {
		return { (error, paymentDevice) in
			if let err = error {
				self.logError(error: err, context: "CONNECT TO READER FAILED")
				onError(err.message!)
			} else {
				if (paymentDevice?.isConnected())! {
					let paymentDeviceId = paymentDevice?.id
					self.log("CONNECT TO READER SUCCESS")
					self.log("PAYMENT DEVICE ID: " + paymentDeviceId!)
					self.readerConnected = true
					self.checkForReaderUpdate(reader: paymentDevice)
					onSuccess("Payment device with ID " + paymentDeviceId! + " found.")
				} else {
					self.log("CONNECT TO READER FAILED - PAYMENT DEVICE NOT CONNECTED")
					onError("A payment device is not connected.")
				}
			}
		}
	}

	func connectToReader(
		onSuccess: @escaping (String) -> Void,
		onError: @escaping (String) -> Void
	) {
		self.log("CONNECT TO READER START")
		let deviceManager = PayPalRetailSDK.deviceManager()
		if (self.merchantInitialized) {
			deviceManager?.connect(toLastActiveReader: self.getConnectToReaderHandler(onSuccess: onSuccess, onError: onError))
		} else {
			onError("Merchant needs to be initialized before you can connect to a payment device.")
		}
	}

	func searchAndConnectToReader(
		onSuccess: @escaping (String) -> Void,
		onError: @escaping (String) -> Void
	) {
		self.log("CONNECT TO READER START")
		let deviceManager = PayPalRetailSDK.deviceManager()
		if (self.merchantInitialized) {
			deviceManager?.searchAndConnect(self.getConnectToReaderHandler(onSuccess: onSuccess, onError: onError))
		} else {
			onError("Merchant needs to be initialized before you can connect to a payment device.")
		}
	}

	func takePayment(
		currencyCode: String,
		total: NSDecimalNumber,
		invoiceNumber: String,
		onSuccess: @escaping (String) -> Void,
		onError: @escaping (String) -> Void
		) {
		self.log("TAKE PAYMENT START")

		if (!self.merchantInitialized) {
			onError("Merchant needs to be initialized before you can take a payment.")
		} else if (!self.readerConnected) {
			onError("A payment device must be connected before you can take a payment.")
		} else {
			var unitPrice = total
			if (total.doubleValue.isLess(than: 1)) {
				unitPrice = 1 as NSDecimalNumber
			}
				
			let invoice: PPRetailInvoice?
			invoice = PPRetailInvoice.init(currencyCode: currencyCode)
			invoice!.addItem("Order", quantity: 1, unitPrice: unitPrice, itemId: 0, detailId: nil)
			if !(invoiceNumber ?? "").isEmpty {
				invoice!.number = invoiceNumber
			}
			self.log("INVOICE NUMBER CHECK")

			PayPalRetailSDK.transactionManager().createTransaction(invoice, callback: { (error, context) in
				if let err = error {
					self.logError(error: err, context: "TAKE PAYMENT FAILED @ CREATE TRANSACTION")
					onError(err.message!)
				} else {
					self.log("TAKE PAYMENT - TRANSACTION CREATED")
					context?.setCompletedHandler { (error, transactionRecord) -> Void in
                        let tx = transactionRecord
                        var logJSON = "{}"
                        if (tx != nil) {
                            logJSON = self.getJSON([
                                "transactionNumber": tx!.transactionNumber != nil ? tx!.transactionNumber! : "",
                                "invoiceId": tx!.invoiceId != nil ? tx!.invoiceId! : "",
                                "authCode": tx!.authCode != nil ? tx!.authCode! : "",
                                "transactionHandle": tx!.transactionHandle != nil ? tx!.transactionHandle! : "",
                                "responseCode": tx!.responseCode != nil ? tx!.responseCode! : "",
                                "correlationId": tx!.correlationId != nil ? tx!.correlationId! : "",
                                "captureId": tx!.captureId != nil ? tx!.captureId! : "",
                                "error": (
                                    error != nil
                                    ? self.getJSONForError(error)
                                    : ""
                                )
                            ])
                        } else {
                            logJSON = self.getJSON([
                                "error": self.getJSON(["message": "No transaction record found."])
                            ])
                        }
						if let err = error {
							self.logError(error: err, context: "TAKE PAYMENT FAILED @ COMPLETED HANDLER")
                            self.log(logJSON)
							onError(logJSON)
						} else {
							self.log("TAKE PAYMENT SUCCESS")
							onSuccess(logJSON)
						}
					}

					let paymentOptions = PPRetailTransactionBeginOptions()
					paymentOptions!.showPromptInCardReader = true 
					paymentOptions!.showPromptInApp = true 
					paymentOptions!.preferredFormFactors = []  
					paymentOptions!.tippingOnReaderEnabled = false
					paymentOptions!.amountBasedTipping = false
					paymentOptions!.isAuthCapture = false

					context?.beginPayment(paymentOptions)
				}
			})
		}
	}

	// ----------------------------------------------------------------------------------------------

	func initializeMerchantCDV(_ command: CDVInvokedUrlCommand) {
		let accessToken = command.arguments[0] as? String ?? ""
		let refreshUrl = command.arguments[1] as? String ?? ""
		let environment = command.arguments[2] as? String ?? ""
		let referrerCode = command.arguments[3] as? String ?? ""

		self.initializeMerchant(
			accessToken: accessToken,
			refreshUrl: refreshUrl,
			environment: environment,
			referrerCode: referrerCode,
			onSuccess: self.getCordovaSuccessCallback(command),
			onError: self.getCordovaErrorCallback(command)
		)
	}

	func connectToReaderCDV(_ command: CDVInvokedUrlCommand) {
		self.connectToReader(
			onSuccess: self.getCordovaSuccessCallback(command),
			onError: self.getCordovaErrorCallback(command)
		)
	}

	func searchAndConnectToReaderCDV(_ command: CDVInvokedUrlCommand) {
		self.searchAndConnectToReader(
			onSuccess: self.getCordovaSuccessCallback(command),
			onError: self.getCordovaErrorCallback(command)
		)
	}

	func takePaymentCDV(_ command: CDVInvokedUrlCommand) {
		let currencyCode = command.arguments[0] as? String ?? ""
		let total = NSDecimalNumber(decimal: ((command.arguments[1] as? NSNumber ?? 1)?.decimalValue)!)
		let invoiceNumber = command.arguments[2] as? String ?? ""
		
		self.takePayment(
			currencyCode: currencyCode,
			total: total,
			invoiceNumber: invoiceNumber,
			onSuccess: self.getCordovaSuccessCallback(command),
			onError: self.getCordovaErrorCallback(command)
		)
	}
}
