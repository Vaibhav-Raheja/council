from app.logx import log


def place(order_id, qty):
    log.emit("info", "placing order", order_id=order_id, qty=qty)
    if qty <= 0:
        log.emit("error", "bad qty", order_id=order_id)
        return False
    log.emit("debug", f"order {order_id} placed")
    return True
