import {

} from 'd3';

export const animation() => {
    let height;
    let width;

    const my = (selection) => {

    };

    my.height = function (_) {
        return arguments.length ? ((height = +_), my) : height;
    };

    my.width = function (_) {
        return arguments.length ? ((width = +_), my) : width;
    };

    return my;
};
