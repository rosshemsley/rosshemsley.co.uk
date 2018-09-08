var inSphere = require("robust-in-sphere")

class Point {
    constructor(x, y) {
        this.x = x;
        this.y = y;
    }
}

let randomPoints = (n, xMin = 0, xMax = 1, yMin = 0, yMax = 1) => {
    let xRange = xMax - xMin;
    let yRange = yMax - yMin;
    let result = [];
    for (var i = 0; i < n; i++) {
        result.push(
            new Point(xMin + xRange * Math.random(), yMin + yRange * Math.random())
        );
    }
    return result;
}

let randInt = (n) => {
    return Math.floor(Math.random() * n); 
}

let circleThroughPoints = (p1, p2, p3) => {
    let denom = 2*(p1.x*(p2.y - p3.y) - p1.y*(p2.x-p3.x) + p2.x*p3.y - p3.x *p2.y);
    let xNum = (p1.x*p1.x+p1.y*p1.y)*(p2.y-p3.y)+(p2.x*p2.x+p2.y*p2.y)*(p3.y-p1.y)+(p3.x*p3.x+p3.y*p3.y)*(p1.y-p2.y);
    let x = xNum / denom;
    let yNum = (p1.x*p1.x+p1.y*p1.y)*(p3.x-p2.x)+(p2.x*p2.x+p2.y*p2.y)*(p1.x-p3.x)+(p3.x*p3.x+p3.y*p3.y)*(p2.x-p1.x);
    let y = yNum / denom;
    let r = Math.sqrt((x-p1.x)*(x-p1.x)+(y-p1.y)*(y-p1.y));
    return {x:x, y:y, r:r};
}

let drawToGraphics = (delaunay, graphics) => {

}

class Triangulation {
    constructor(points) {
        // points are stored as {x:0, y:0} objects.
        this.points = points;
        // triangles are stored as sorted triples of indices into the points array.
        this.triangles = [];
    }

    addTriangle(i, j, k) {
        if (this.hasTriangle(i, j, k)) {
            return
        }

        let tr = [i, j, k].sort();
        this.triangles.push(tr)
    }

    hasTriangle(i, j, k) {
        let tr = [i, j, k].sort();

        for (let t of this.triangles) {
            if (t[0] == tr[0] && t[1] == tr[1] && t[2] == tr[2]) {
                return true
            }
        }

        return false
    }
}
