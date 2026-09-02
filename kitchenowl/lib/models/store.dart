import 'model.dart';

class Store extends Model {
  final int? id;
  final String name;
  final String? photo;
  final String? photoHash;

  const Store({this.id, this.name = "", this.photo, this.photoHash});

  factory Store.fromJson(Map<String, dynamic> map) => Store(
        id: map['id'],
        name: map['name'] ?? "",
        photo: map['photo'],
        photoHash: map['photo_hash'],
      );

  @override
  List<Object?> get props => [id, name, photo, photoHash];

  @override
  Map<String, dynamic> toJson() => {
        "name": name,
        if (photo != null) "photo": photo,
      };

  @override
  Map<String, dynamic> toJsonWithId() => toJson()
    ..addAll({
      "id": id,
      if (photoHash != null) "photo_hash": photoHash,
    });

  Store copyWith({String? name, String? photo}) => Store(
        id: id,
        name: name ?? this.name,
        photo: photo ?? this.photo,
        photoHash: photo != null ? null : photoHash,
      );
}
