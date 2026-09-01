from datetime import datetime

from app.config import app, scheduler
from app import socketio
from app.service.price_refresh import eligible_price_ids, refresh_batch

_BATCH_SIZE = 10
_INTERVAL_SECONDS = 60


def _job_id(household_id: int) -> str:
    return f"price_refresh_{household_id}"


def start_price_refresh(household_id: int, batch_size: int = _BATCH_SIZE) -> int:
    """Kicks off a rate-limited refresh of every Aldi/dm-linked price in this
    household, `batch_size` at a time every `_INTERVAL_SECONDS` seconds, so
    the external APIs aren't hit all at once. Returns the number of prices
    queued for refresh, or -1 if a refresh is already running for this
    household."""
    ids = eligible_price_ids(household_id)

    if scheduler is None:
        # Celery-configured deployments have no worker consuming this job
        # (see app/jobs/jobs.py for the same scheduler/celery split) - running
        # the whole (typically small) backlog synchronously here is simpler
        # than standing up a second, parallel job mechanism just for this.
        refresh_batch(ids)
        return len(ids)

    job_id = _job_id(household_id)
    if scheduler.get_job(job_id):
        return -1
    if not ids:
        return 0

    remaining = list(ids)

    def tick():
        batch, remaining[:] = remaining[:batch_size], remaining[batch_size:]
        with app.app_context():
            result = refresh_batch(batch)
            socketio.emit(
                "pricerefresh:progress",
                {
                    "refreshed": len(ids) - len(remaining),
                    "total": len(ids),
                    **result,
                },
                to="household/" + str(household_id),
            )
            if not remaining:
                socketio.emit(
                    "pricerefresh:done",
                    {"total": len(ids)},
                    to="household/" + str(household_id),
                )
                scheduler.remove_job(job_id)

    scheduler.add_job(
        id=job_id,
        func=tick,
        trigger="interval",
        seconds=_INTERVAL_SECONDS,
        next_run_time=datetime.now(),
    )

    return len(ids)
