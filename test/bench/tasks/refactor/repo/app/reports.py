from app.logx import legacy_log

SEVERITY = {True: "error", False: "info"}


def build(rows):
    failed = [r for r in rows if r.get("failed")]
    legacy_log("report built", SEVERITY[bool(failed)], n=len(rows), failed=len(failed))
    return {"rows": len(rows), "failed": len(failed)}
