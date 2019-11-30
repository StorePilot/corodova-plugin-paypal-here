var exec = require('cordova/exec')

const parseString = val => (val || '').toString()
const parseNumber = val => (Number(val) || 0)

exports.initializeMerchant = function (args, success, error) {
  args = args || {}
  exec(success, error, 'CDVPayPalHere', 'initializeMerchantCDV', [
    parseString(args.accessToken),
    parseString(args.refreshUrl),
    parseString(args.environment),
    parseString(args.referrerCode)
  ])
}

exports.connectToReader = function (args, success, error) {
  args = args || {}
  exec(success, error, 'CDVPayPalHere', 'connectToReaderCDV', [
  ])
}

exports.searchAndConnectToReader = function (args, success, error) {
  args = args || {}
  exec(success, error, 'CDVPayPalHere', 'searchAndConnectToReaderCDV', [
  ])
}

exports.takePayment = function (args, success, error) {
  args = args || {}
  exec(success, error, 'CDVPayPalHere', 'takePaymentCDV', [
    parseString(args.currencyCode),
    parseNumber(args.total),
    parseString(args.invoiceNumber)
  ])
}

