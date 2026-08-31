from __future__ import annotations
from typing import Any, Self, List, TYPE_CHECKING, cast
from app import db
from app.helpers import DbModelAuthorizeMixin
from sqlalchemy.orm import Mapped

Model = db.Model
if TYPE_CHECKING:
    from app.models import Household, Item
    from app.helpers.db_model_base import DbModelBase

    Model = DbModelBase


class Store(Model, DbModelAuthorizeMixin):
    __tablename__ = "store"

    id: Mapped[int] = db.Column(db.Integer, primary_key=True)
    name: Mapped[str] = db.Column(db.String(128))
    household_id: Mapped[int] = db.Column(
        db.Integer, db.ForeignKey("household.id"), nullable=False, index=True
    )

    household: Mapped["Household"] = cast(
        Mapped["Household"],
        db.relationship(
            "Household",
            uselist=False,
            foreign_keys=[household_id],
        ),
    )
    prices: Mapped[List["ItemPrice"]] = cast(
        Mapped[List["ItemPrice"]],
        db.relationship(
            "ItemPrice",
            back_populates="store",
            cascade="all, delete-orphan",
        ),
    )

    @classmethod
    def find_by_name(cls, household_id: int, name: str) -> Self | None:
        return cls.query.filter(
            cls.name == name, cls.household_id == household_id
        ).first()


class ItemPrice(Model, DbModelAuthorizeMixin):
    __tablename__ = "item_price"

    id: Mapped[int] = db.Column(db.Integer, primary_key=True)
    item_id: Mapped[int] = db.Column(
        db.Integer, db.ForeignKey("item.id"), nullable=False, index=True
    )
    store_id: Mapped[int] = db.Column(
        db.Integer, db.ForeignKey("store.id"), nullable=False, index=True
    )
    household_id: Mapped[int] = db.Column(
        db.Integer, db.ForeignKey("household.id"), nullable=False, index=True
    )
    # price of ONE pack
    price: Mapped[float] = db.Column(db.Float, nullable=False)
    pack_amount: Mapped[float] = db.Column(db.Float, nullable=False, default=1.0)
    pack_unit: Mapped[str] = db.Column(db.String(16), nullable=False, default="piece")

    item: Mapped["Item"] = cast(
        Mapped["Item"],
        db.relationship(
            "Item",
            back_populates="prices",
        ),
    )
    store: Mapped["Store"] = cast(
        Mapped["Store"],
        db.relationship(
            "Store",
            back_populates="prices",
        ),
    )

    __table_args__ = (
        db.UniqueConstraint("item_id", "store_id", name="uq_item_price_item_store"),
    )

    def obj_to_dict(
        self,
        skip_columns: list[str] | None = None,
        include_columns: list[str] | None = None,
    ) -> dict[str, Any]:
        res = super().obj_to_dict(skip_columns, include_columns)
        res["store"] = self.store.obj_to_dict()
        return res

    @classmethod
    def find_by_item_store(cls, item_id: int, store_id: int) -> Self | None:
        return cls.query.filter(
            cls.item_id == item_id, cls.store_id == store_id
        ).first()

    @classmethod
    def all_by_item(cls, item_id: int) -> list[Self]:
        return cls.query.filter(cls.item_id == item_id).all()
