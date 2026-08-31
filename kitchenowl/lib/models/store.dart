import 'model.dart';

class Store extends Model {
  final int? id;
  final String name;

  const Store({this.id, this.name = ""});

  factory Store.fromJson(Map<String, dynamic> map) => Store(
        id: map['id'],
        name: map['name'] ?? "",
      );

  @override
  List<Object?> get props => [id, name];

  @override
  Map<String, dynamic> toJson() => {
        "name": name,
      };

  @override
  Map<String, dynamic> toJsonWithId() => toJson()
    ..addAll({
      "id": id,
    });

  Store copyWith({String? name}) => Store(
        id: id,
        name: name ?? this.name,
      );
}
