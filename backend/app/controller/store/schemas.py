from marshmallow import fields, Schema, EXCLUDE


class AddStore(Schema):
    class Meta:
        unknown = EXCLUDE

    name = fields.String(required=True, validate=lambda a: a and not a.isspace())


class UpdateStore(Schema):
    class Meta:
        unknown = EXCLUDE

    name = fields.String(validate=lambda a: a and not a.isspace())
