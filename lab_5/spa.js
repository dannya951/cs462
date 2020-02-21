angular.module('spa', [])
.controller('MainCtrl', [
  '$scope','$http','$window',
  function($scope,$http,$window){
    $scope.profile = {};
    $scope.current_temperature = "";
    $scope.temperatures = [];
    $scope.threshold_violations = [];
    $scope.eci = $window.location.search.substring(1);
    $scope.temperatures_page = true;
 
    var ctURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/current_temperature';
    $scope.get_current_temperature = function () {
      return $http.get(ctURL).success(function(data){
        //$scope.current_temperature = data;
        angular.copy(data, $scope.current_temperature);
      });
    };

    $scope.get_current_temperature();

    var tURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/temperatures';
    $scope.get_temperatures = function() {
      return $http.get(tURL).success(function(data) {
        angular.copy(data, $scope.temperatures);
      });
    };

    $scope.get_temperatures();

    var tvURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/threshold_violations';
    $scope.get_threshold_violations = function() {
      return $http.get(tvURL).success(function(data){
        angular.copy(data, $scope.threshold_violations);
      });
    };

    $scope.get_threshold_violations();

    var ppuURL = 'http://localhost:8080/sky/event/'+$scope.eci+'/000/sensor/profile_updated';
    $scope.profile_updated = function() {
      var puURL = ppuURL + "?location=" + $scope.location + "&name=" + $scope.name+ "&threshold=" + $scope.threshold + "&number=" + $scope.number;
      return $http.post(puURL).success(function(data){
        $scope.get_profile();
        $scope.location = '';
        $scope.name = '';
        $scope.threshold = '';
        $scope.number = '';
      });
    };

    var gpURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/sensor_profile/profile';
    $scope.get_profile = function() {
      return $http.get(gpURL).success(function(data){
        angular.copy(data, $scope.profile);
      });
    };

    $scope.get_profile();

    $scope.toggle_page = function() {
      $scope.temperatures_page = !($scope.temperatures_page);
    };
  }
]);
