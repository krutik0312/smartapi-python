from smartapi import SmartConnect
import datetime, time

API_KEY = "your_api_key"
CLIENT_ID = "your_client_id"
API_SECRET = "your_api_secret"
PIN = "your_pin"

event_dates = {"2025-11-22", "2025-12-06"}  # Example: fill with actual RBI, Fed, Budget dates, etc.

capital = 5000000
margin_used = int(capital * 0.6)
max_daily_loss = 30000
max_daily_profit = 30000

api = SmartConnect(api_key=API_KEY)
api.generateSession(CLIENT_ID, PIN, API_SECRET)  # Authenticate

def is_event_day():
    today = datetime.date.today().strftime('%Y-%m-%d')
    return today in event_dates

def get_nifty_spot():
    # Get NIFTY spot price from Angel API, fill as per documentation
    nifty_quote = api.ltpData('NSE', 'NIFTY', '26009')
    # Instrument token above is illustrative; use correct one from Angel docs
    spot = float(nifty_quote['data']['ltp'])
    # Round ATM to nearest 50, standard for NIFTY
    atm = round(spot / 50) * 50
    return atm

def find_otm_strike(atm_strike, offset=300):
    call_strike = atm_strike + offset
    put_strike  = atm_strike - offset
    return call_strike, put_strike

def get_option_token(strike, opt_type, expiry):
    # Use Angel's API to look up option symbol & instrument token
    # Refer Angel One's contracts.csv or their symbol search endpoint
    pass

def calculate_lot_size(margin):
    margin_per_lot = 120000  # Assume average, adjust for OTM hedging
    max_lots = int(margin // margin_per_lot)
    return max_lots * 25  # NIFTY lot is 25

def place_sell_order(token, qty):
    # Place sell order per Angel SmartAPI documentation
    # order = api.placeOrder(...) fill this
    pass

def get_positions():
    # Use Angel One's API
    # positions = api.getPositions()
    pass

def get_mtm(order_ids):
    # Compute live combined MTM P&L for all legs
    pass

def square_off(order_ids):
    # Place opposite buy order for all open shorts to exit position
    pass

def main():
    if is_event_day():
        print("Event day, no trade.")
        return

    atm = get_nifty_spot()
    call_strike, put_strike = find_otm_strike(atm)
    expiry = "next Thursday expiry"  # Use Angel's contract API to get correct expiry
    qty = calculate_lot_size(margin_used)

    call_token = get_option_token(call_strike, 'CE', expiry)
    put_token  = get_option_token(put_strike, 'PE', expiry)

    order_call = place_sell_order(call_token, qty)
    order_put  = place_sell_order(put_token, qty)
    order_ids  = [order_call, order_put]

    while datetime.datetime.now().time() < datetime.time(15, 15):
        mtm = get_mtm(order_ids)
        if mtm <= -max_daily_loss:
            square_off(order_ids)
            print("Exited on loss")
            return
        elif mtm >= max_daily_profit:
            square_off(order_ids)
            print("Exited on profit")
            return
        time.sleep(30)  # Poll every 30 seconds

    # End of day square off
    square_off(order_ids)
    print("Exited on time.")

if __name__ == "__main__":
    main()
