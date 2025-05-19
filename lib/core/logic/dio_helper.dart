import 'package:dio/dio.dart';

class DioHelper {
  final Dio _dio = Dio(
    BaseOptions(baseUrl: "https://vcare.integration25.com/api"),
  );
  Future<CustomResponse> sendData(String endPoint,
      {Map<String, dynamic>? data}) async {
    print("(POST) https://vcare.integration25.com/api$endPoint");
    print("Data:$data");
    try {
      final response = await _dio.post(
        endPoint,
        data: data,
      );
      print(response.data);
      return CustomResponse(
          message: response.data["message"],
          isSuccess: true,
          response: response);
    } on DioException catch (ex) {
      print(ex);
      return CustomResponse(
          message: ex.response?.data["message"] ?? "",
          isSuccess: false,
          response: ex.response);
    }
  }

  Future<CustomResponse> getData(String endPoint,
      {Map<String, dynamic>? data}) async {
    print("(POST) https://vcare.integration25.com/api$endPoint");
    print("Data:$data");
    try {
      final response = await _dio.get(
        endPoint,
        queryParameters: data,
      );
      print(response.data);
      return CustomResponse(
          message: response.data["message"],
          isSuccess: true,
          response: response);
    } on DioException catch (ex) {
      print(ex);
      return CustomResponse(
          message: ex.response?.data["message"] ?? "",
          isSuccess: false,
          response: ex.response);
    }
  }
}

class CustomResponse {
  late final String message;
  late final bool isSuccess;
  late final Response? response;

  CustomResponse(
      {required this.message, required this.isSuccess, this.response});
}
