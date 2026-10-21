from app.logx import legacy_log


def place(order_id, qty):
    legacy_log("placing order", order_id=order_id, qty=qty)
    if qty <= 0:
        legacy_log("bad qty", "error", order_id=order_id)
        return False
    legacy_log(f"order {order_id} placed", level="debug")
    return True
