angular.module('spa', [])
.directive('focusInput', function($timeout) {
  return {
    link: function(scope, element, attrs) {
      element.bind('click', function() {
        $timeout(function() {
          element.parent().find('input')[0].focus();
        });
      });
    }
  };
})
.controller('MainCtrl', [
  '$scope','$http','$window',
  function($scope,$http,$window){

    //$scope.timings = [];
    $scope.current_temperature = "No Reading Yet";
    $scope.temperatures = [];
    $scope.threshold_violations = [];
    $scope.eci = $window.location.search.substring(1);

    /*
    var bURL = 'http://localhost:8080/sky/event/'+$scope.eci+'/eid/timing/started';
    $scope.addTiming = function() {
      var pURL = bURL + "?number=" + $scope.number + "&name=" + $scope.name;
      return $http.post(pURL).success(function(data){
        $scope.getAll();
        $scope.number='';
        $scope.name='';
      });
    };
    */
 
    /*
    var iURL = 'http://localhost:8080/sky/event/'+$scope.eci+'/eid/timing/finished';
    $scope.finished = function(number) {
      var pURL = iURL + "?number=" + number;
      return $http.post(pURL).success(function(data){
        $scope.getAll();
      });
    };
    */
 
    /*
    var gURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/timing_tracker/entries';
    $scope.getAll = function() {
      return $http.get(gURL).success(function(data){
        angular.copy(data, $scope.timings);
      });
    };
 
    $scope.getAll();
    */
    var ctURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/current_temperature';
    $scope.get_current_temperature = function () {
      return $http.get(ctURL).success(function(data){
        $scope.current_temperature = data;
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
    $scope.get_threshold_violations() {
      return $http.get(tvURL).success(function(data){
        angular.copy(data, $scope.threshold_violations);
      });
    };

    $scope.get_threshold_violations();
 
    /*
    $scope.timeDiff = function(timing) {
      var bgn_sec = Math.round(Date.parse(timing.time_out)/1000);
      var end_sec = Math.round(Date.parse(timing.time_in)/1000);
      var sec_num = end_sec - bgn_sec;
      var hours   = Math.floor(sec_num / 3600);
      var minutes = Math.floor((sec_num - (hours * 3600)) / 60);
      var seconds = sec_num - (hours * 3600) - (minutes * 60);
   
      if (hours   < 10) {hours   = "0"+hours;}
      if (minutes < 10) {minutes = "0"+minutes;}
      if (seconds < 10) {seconds = "0"+seconds;}
      return hours+':'+minutes+':'+seconds;
    }
    */
  }
]);
